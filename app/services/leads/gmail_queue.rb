module Leads
  # Queues approved leads for staggered Gmail delivery.
  # Order is shuffled; delay between each send is random; times snap into the NY send window.
  class GmailQueue
    DEFAULT_MIN_MINUTES = 8
    DEFAULT_MAX_MINUTES = 13

    def self.call(lead_ids)
      new(lead_ids).call
    end

    def initialize(lead_ids)
      @lead_ids = Array(lead_ids)
    end

    def call
      leads = Lead.where(id: @lead_ids).to_a.select(&:bulk_sendable?)
      return 0 if leads.empty?

      shuffled = leads.shuffle
      send_at = nil

      shuffled.each_with_index do |lead, index|
        gap_minutes = 0

        if send_at.nil?
          send_at = GmailSendWindow.next_open_at(Time.current)
        else
          gap_minutes = random_delay_minutes
          send_at = GmailSendWindow.next_open_at(send_at + gap_minutes.minutes)
        end

        lead.update!(
          status: :queued,
          error_message: nil,
          raw_data: lead.raw_data.merge(
            "gmail_queue" => {
              "queued_at" => Time.current.iso8601,
              "position" => index + 1,
              "total" => shuffled.size,
              "gap_minutes" => gap_minutes,
              "send_after" => send_at.iso8601,
              "send_after_local" => send_at.in_time_zone(GmailSendWindow.timezone).strftime("%Y-%m-%d %H:%M %Z"),
              "window" => GmailSendWindow.label
            }
          )
        )

        Leads::GmailSendJob.set(wait_until: send_at).perform_later(lead.id)
      end

      shuffled.size
    end

    def self.delay_range_label
      "#{min_minutes}–#{max_minutes} min"
    end

    def self.min_minutes
      ENV.fetch("GMAIL_SEND_DELAY_MIN_MINUTES", DEFAULT_MIN_MINUTES.to_s).to_i.clamp(1, 180)
    end

    def self.max_minutes
      [ ENV.fetch("GMAIL_SEND_DELAY_MAX_MINUTES", DEFAULT_MAX_MINUTES.to_s).to_i.clamp(1, 180), min_minutes ].max
    end

    private

    def random_delay_minutes
      rand(self.class.min_minutes..self.class.max_minutes)
    end
  end
end
