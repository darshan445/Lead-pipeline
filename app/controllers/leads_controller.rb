class LeadsController < ApplicationController
  def index
    visible_leads = Lead.order(created_at: :desc).reject(&:hidden_from_ui?)
    @lead_counts = visible_leads.each_with_object(Hash.new(0)) do |lead, counts|
      counts[:all] += 1
      counts[lead.status.to_sym] += 1
    end
    @gmail_ready = GmailClient.configured?

    @leads = visible_leads
    @leads = @leads.select { |lead| lead.status == params[:status] } if params[:status].present?
  end

  def show
    @lead = Lead.find(params[:id])
    if @lead.hidden_from_ui?
      redirect_to leads_path, alert: "That company record is hidden after employee selection." and return
    end
  end

  def discover
    query = params[:query].to_s.strip
    max_results = (params[:max_results].presence || Leads::DiscoveryJob::MAX_RESULTS).to_i
      .clamp(1, Leads::DiscoveryJob::MAX_RESULTS)

    if query.blank?
      redirect_to leads_path, alert: "Please provide a search query." and return
    end

    Leads::DiscoveryJob.perform_later(query, max_results)

    redirect_to leads_path, notice: "Discovery started for: #{query} (up to #{max_results} companies)"
  end

  def bulk_destroy
    ids = Array(params[:lead_ids]).map(&:presence).compact
    if ids.empty?
      redirect_to leads_path, alert: "Select at least one lead to delete." and return
    end

    deleted_count = Lead.where(id: ids).destroy_all.size
    redirect_to leads_path, notice: "Deleted #{deleted_count} lead#{'s' unless deleted_count == 1}."
  end

  def bulk_send_pitch
    ids = Array(params[:lead_ids]).map(&:presence).compact
    if ids.empty?
      redirect_to leads_path(bulk_redirect_params), alert: "Select at least one lead to send." and return
    end

    unless GmailClient.configured?
      redirect_to leads_path(bulk_redirect_params),
        alert: "Gmail is not connected yet. Connect Gmail first, then try again." and return
    end

    leads = Lead.where(id: ids)
    sendable = leads.select(&:bulk_sendable?)
    skipped = leads.size - sendable.size

    if sendable.empty?
      redirect_to leads_path(bulk_redirect_params),
        alert: "No selected leads are ready to send. They must be Pitched or Sent, with an email and generated pitch." and return
    end

    queued_count = Leads::GmailQueue.call(sendable.map(&:id))
    range = Leads::GmailQueue.delay_range_label
    window = Leads::GmailSendWindow.label

    notice = "Queued #{queued_count} email#{'s' unless queued_count == 1} via Gmail (randomized order, #{range} between sends, only during #{window})."
    notice += " Skipped #{skipped} not eligible." if skipped.positive?
    redirect_to leads_path(bulk_redirect_params), notice: notice
  end

  def retry
    lead = Lead.find(params[:id])
    result = Leads::RetryRunner.call(lead)

    if result.retried?
      redirect_back_or_to leads_path, notice: result.message
    else
      redirect_back_or_to leads_path, alert: result.message
    end
  end

  def bulk_retry
    ids = Array(params[:lead_ids]).map(&:presence).compact
    if ids.empty?
      redirect_to leads_path(bulk_redirect_params), alert: "Select at least one lead to retry." and return
    end

    results = Lead.where(id: ids).map { |lead| Leads::RetryRunner.call(lead) }
    retried = results.count(&:retried?)
    skipped = results.size - retried

    if retried.zero?
      redirect_to leads_path(bulk_redirect_params),
        alert: "None of the selected leads are retryable. Only Failed, Rejected, or empty-employee leads can be retried." and return
    end

    notice = "Retrying #{retried} lead#{'s' unless retried == 1}..."
    notice += " Skipped #{skipped} not retryable." if skipped.positive?
    redirect_to leads_path(bulk_redirect_params), notice: notice
  end

  def generate_pitch
    lead = Lead.find(params[:id])

    unless lead.person_lead?
      redirect_to lead_path(lead), alert: "Pitch only for people leads, not company pages." and return
    end

    personalization = params[:personalization].to_s.strip.presence
    persist_pitch_personalization!(lead, personalization)
    Leads::PitchGenerationJob.perform_later(lead.id, personalization: personalization)

    redirect_to lead_path(lead), notice: "Generating pitch..."
  end

  def find_email
    lead = Lead.find(params[:id])

    unless lead.person_lead?
      redirect_to lead_path(lead), alert: "Email find is only for people leads." and return
    end

    result = Leads::EmailFinder.call(lead)

    if result.email.present?
      redirect_to lead_path(lead), notice: "Email found: #{result.email}"
    else
      redirect_to lead_path(lead), alert: "No email found for #{lead.profile_name}."
    end
  rescue Leads::EmailFinder::Error, AnymailfinderClient::Error => e
    redirect_to lead_path(lead), alert: e.message
  end

  def update_email
    lead = Lead.find(params[:id])

    unless lead.person_lead?
      redirect_to lead_path(lead), alert: "Email can only be set for people leads." and return
    end

    email = params[:email].to_s.strip
    if email.blank?
      redirect_to lead_path(lead), alert: "Email address is required." and return
    end

    lead.update!(email: email)

    redirect_to lead_path(lead), notice: "Lead email saved."
  end

  private

  def persist_pitch_personalization!(lead, personalization)
    data = (lead.raw_data || {}).deep_dup
    if personalization.present?
      data[Leads::PitchGenerator::PERSONALIZATION_KEY] = personalization
    else
      data.delete(Leads::PitchGenerator::PERSONALIZATION_KEY)
    end
    lead.update!(raw_data: data)
  end

  def bulk_redirect_params
    params[:status].present? ? { status: params[:status] } : {}
  end
end
