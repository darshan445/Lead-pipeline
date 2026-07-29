module Leads
  # Normalizes pitch body spacing and sign-off for consistent email/UI rendering.
  class PitchBodyNormalizer
    GREETING_REGEX = /\A(Hi [^,\n]+,|Hi there,)\s*/i
    SIGN_OFF_TAIL_REGEX = /\n*(Best[,.]?\s*\n\s*\*{0,2}Darsh(?:\s+T|\s+Thakor)?\.?\*{0,2}\s*|Best regards,?\s*\n.*|Thanks,?\s*\n.*|Cheers,?\s*\n.*)\z/i

    def self.call(body)
      new(body).call
    end

    def initialize(body)
      @body = body.to_s.gsub("\r\n", "\n").strip
    end

    def call
      return "" if @body.blank?

      text = strip_existing_sign_off(@body)
      text = ensure_blank_line_after_greeting(text)
      text = collapse_excess_blank_lines(text.strip)
      "#{text}\n\n#{PitchGenerator::SIGN_OFF}"
    end

    private

    def strip_existing_sign_off(text)
      text.sub(SIGN_OFF_TAIL_REGEX, "").rstrip
    end

    def ensure_blank_line_after_greeting(text)
      match = text.match(GREETING_REGEX)
      return text unless match

      greeting = match[1]
      rest = text[match.end(0)..].to_s.lstrip
      "#{greeting}\n\n#{rest}"
    end

    def collapse_excess_blank_lines(text)
      text.gsub(/\n{3,}/, "\n\n")
    end
  end
end
