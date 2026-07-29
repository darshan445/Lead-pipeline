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
      redirect_to leads_path(bulk_send_redirect_params), alert: "Select at least one lead to send." and return
    end

    unless GmailClient.configured?
      redirect_to leads_path(bulk_send_redirect_params),
        alert: "Gmail is not connected yet. Connect Gmail first, then try again." and return
    end

    leads = Lead.where(id: ids)
    sendable = leads.select(&:bulk_sendable?)
    skipped = leads.size - sendable.size

    if sendable.empty?
      redirect_to leads_path(bulk_send_redirect_params),
        alert: "No selected leads are ready to send. They must be Pitched or Sent, with an email and generated pitch." and return
    end

    queued_count = Leads::GmailQueue.call(sendable.map(&:id))
    range = Leads::GmailQueue.delay_range_label
    window = Leads::GmailSendWindow.label

    notice = "Queued #{queued_count} email#{'s' unless queued_count == 1} via Gmail (randomized order, #{range} between sends, only during #{window})."
    notice += " Skipped #{skipped} not eligible." if skipped.positive?
    redirect_to leads_path(bulk_send_redirect_params), notice: notice
  end

  def retry
    lead = Lead.find(params[:id])

    unless lead.retryable?
      redirect_to lead_path(lead), alert: "This lead is not retryable." and return
    end

    case lead.retry_stage
    when :scrape
      Leads::LinkedinScrapeJob.perform_later([ lead.id ])
      message = "Retrying company scrape..."
    when :qualify
      lead.update!(status: :qualifying, error_message: nil)
      Leads::LinkedinQualifyJob.perform_later(lead.id)
      message = "Retrying company qualification..."
    when :employee_select
      lead.update!(status: :employee_discovery, error_message: nil)
      Leads::LinkedinEmployeesJob.perform_later(lead.id)
      message = "Retrying employee discovery and selection..."
    when :pitch
      Leads::PitchGenerationJob.perform_later(lead.id)
      message = "Retrying pitch generation..."
    when :send
      Leads::GmailSendJob.perform_later(lead.id)
      message = "Retrying Gmail send..."
    else
      redirect_to lead_path(lead), alert: "Could not determine which step to retry." and return
    end

    redirect_to lead_path(lead), notice: message
  end

  def generate_pitch
    lead = Lead.find(params[:id])

    unless lead.person_lead?
      redirect_to lead_path(lead), alert: "Pitch only for people leads, not company pages." and return
    end

    Leads::PitchGenerationJob.perform_later(lead.id)

    redirect_to lead_path(lead), notice: "Generating pitch..."
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

  def bulk_send_redirect_params
    params[:status].present? ? { status: params[:status] } : {}
  end
end
