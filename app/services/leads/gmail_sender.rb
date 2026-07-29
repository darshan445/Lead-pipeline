module Leads
  # Sends one lead email via Gmail API as darsh@getscotive.com.
  class GmailSender
    def self.call(lead_id)
      new(lead_id).call
    end

    def initialize(lead_id)
      @lead_id = lead_id
    end

    def call
      lead = Lead.find(@lead_id)

      unless GmailSendWindow.open?
        reschedule_inside_window!(lead)
        return
      end

      lead.update!(status: :sending, error_message: nil)

      subject, body = resolve_pitch(lead)
      if subject.blank? || body.blank?
        raise "Pitch must include a subject line and body"
      end
      if lead.email.blank?
        raise "Lead email is required before sending via Gmail"
      end

      body = Leads::PitchBodyNormalizer.call(body)

      response = GmailClient.new.send_email(
        to: lead.email,
        subject: subject,
        text_body: body,
        html_body: Leads::PitchHtmlFormatter.call(body)
      )

      lead.update!(
        status: :sent,
        error_message: nil,
        raw_data: lead.raw_data.merge(
          "gmail" => {
            "sent_at" => Time.current.iso8601,
            "message_id" => response["id"],
            "thread_id" => response["threadId"],
            "response" => response
          }
        )
      )
    rescue => e
      lead&.update(status: :failed, error_message: e.message)
    end

    private

    def reschedule_inside_window!(lead)
      send_at = GmailSendWindow.next_open_at(Time.current)
      lead.update!(
        status: :queued,
        error_message: nil,
        raw_data: lead.raw_data.merge(
          "gmail_queue" => (lead.raw_data["gmail_queue"] || {}).merge(
            "rescheduled_at" => Time.current.iso8601,
            "send_after" => send_at.iso8601,
            "send_after_local" => send_at.in_time_zone(GmailSendWindow.timezone).strftime("%Y-%m-%d %H:%M %Z"),
            "window" => GmailSendWindow.label
          )
        )
      )
      Leads::GmailSendJob.set(wait_until: send_at).perform_later(lead.id)
    end

    def resolve_pitch(lead)
      subject = lead.pitch_subject
      body = lead.pitch_body

      if subject.blank? || body.blank?
        parsed = Leads::PitchParser.call(lead.pitch_content)
        subject = subject.presence || parsed.subject
        body = body.presence || parsed.body
      end

      [ subject, body ]
    end
  end
end
