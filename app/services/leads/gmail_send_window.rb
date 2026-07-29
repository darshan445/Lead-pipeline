module Leads
  # Restricts Gmail sends to a daily window in a given timezone (default 6 AM–5 PM America/New_York).
  class GmailSendWindow
    DEFAULT_TIMEZONE = "America/New_York"
    DEFAULT_START_HOUR = 6  # 6 AM inclusive
    DEFAULT_END_HOUR = 17   # 5 PM exclusive (no sends at/after 5:00 PM)

    def self.timezone
      ActiveSupport::TimeZone[ENV.fetch("GMAIL_SEND_TIMEZONE", DEFAULT_TIMEZONE)] ||
        ActiveSupport::TimeZone[DEFAULT_TIMEZONE]
    end

    def self.start_hour
      ENV.fetch("GMAIL_SEND_WINDOW_START_HOUR", DEFAULT_START_HOUR.to_s).to_i.clamp(0, 23)
    end

    def self.end_hour
      hour = ENV.fetch("GMAIL_SEND_WINDOW_END_HOUR", DEFAULT_END_HOUR.to_s).to_i.clamp(1, 24)
      [ hour, start_hour + 1 ].max
    end

    def self.label
      zone = timezone
      start_label = zone.now.change(hour: start_hour, min: 0).strftime("%-l %p")
      end_label = zone.now.change(hour: end_hour, min: 0).strftime("%-l %p")
      "#{start_label}–#{end_label} #{zone.name}"
    end

    def self.open?(at: Time.current)
      local = at.in_time_zone(timezone)
      local >= window_start_on(local) && local < window_end_on(local)
    end

    # Earliest moment at or after `at` that falls inside the send window.
    def self.next_open_at(at = Time.current)
      local = at.in_time_zone(timezone)
      start_at = window_start_on(local)
      end_at = window_end_on(local)

      if local < start_at
        start_at
      elsif local >= end_at
        start_at + 1.day
      else
        local
      end
    end

    def self.window_start_on(local_time)
      local_time.change(hour: start_hour, min: 0, sec: 0)
    end

    def self.window_end_on(local_time)
      local_time.change(hour: end_hour, min: 0, sec: 0)
    end
  end
end
