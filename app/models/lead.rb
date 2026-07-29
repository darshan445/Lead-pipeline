class Lead < ApplicationRecord
  belongs_to :agent, optional: true

  enum :source, { instagram: "instagram", linkedin: "linkedin" }
  enum :pitch_type, { email: "email", dm: "dm" }, prefix: :pitch, validate: { allow_nil: true }
  enum :status, {
    discovered: "discovered",
    scraping: "scraping",
    qualifying: "qualifying",
    rejected: "rejected",
    email_discovery: "email_discovery",
    employee_discovery: "employee_discovery",
    ready: "ready",
    pitching: "pitching",
    pitched: "pitched",
    queued: "queued",
    sending: "sending",
    sent: "sent",
    failed: "failed"
  }

  validates :query, presence: true
  validates :profile_url, presence: true, uniqueness: true

  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated
  after_update_commit -> { broadcast_replace_to self, :detail, target: [ self, :detail ], partial: "leads/detail", locals: { lead: self } }

  def profile_name
    person_name = [ raw_data["firstName"], raw_data["lastName"] ].map(&:presence).compact.join(" ")
    person_name.presence ||
      raw_data["fullName"] ||
      raw_data["companyName"] ||
      raw_data["full_name"] ||
      raw_data["name"] ||
      raw_data["username"] ||
      profile_url
  end

  # Person leads created from employee selection (pitchable). Companies are intermediate.
  def person_lead?
    profile_url.to_s.include?("/in/") || raw_data["firstName"].present?
  end

  def company_lead?
    profile_url.to_s.include?("/company/")
  end

  # Hide intermediate company records after we've found employee leads to pursue.
  def hidden_from_ui?
    company_lead? && raw_data["selected_employee_urls"].present?
  end

  # Eligible for bulk send from the index (pitched or already sent, has email and pitch).
  def bulk_sendable?
    person_lead? && (pitched? || sent?) && pitch_ready? && email.present? && !queued? && !sending?
  end

  def pitch_ready?
    (pitch_subject.present? && pitch_body.present?) || pitch_content.present?
  end

  def retryable?
    failed?
  end

  # Best-effort resume point based on what data the lead already has.
  def retry_stage
    if company_lead?
      return :scrape if raw_data.blank?
      return :qualify if raw_data["qualification_analysis"].blank?
      return :employee_select if raw_data["employee_selection_analysis"].blank?
    end

    return :send if person_lead? && pitch_ready?
    return :pitch if person_lead?

    nil
  end

  # Prefer stored columns; fall back to parsing combined pitch_content for older rows.
  def display_pitch_subject
    pitch_subject.presence || parsed_pitch.subject
  end

  def display_pitch_body
    raw = pitch_body.presence || parsed_pitch.body || pitch_content
    return raw if raw.blank?

    Leads::PitchBodyNormalizer.call(raw)
  end

  def display_pitch_body_html
    Leads::PitchHtmlFormatter.call(display_pitch_body.to_s)
  end

  private

  def parsed_pitch
    @parsed_pitch ||= Leads::PitchParser.call(pitch_content)
  end

  def broadcast_created
    return if hidden_from_ui?

    broadcast_append_to :leads, target: "leads", partial: "leads/lead_row", locals: { lead: self }
  end

  def broadcast_updated
    if hidden_from_ui?
      broadcast_remove_to :leads, target: self
      return
    end

    broadcast_replace_to :leads, partial: "leads/lead_row", locals: { lead: self }
  end
end
