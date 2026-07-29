module Leads
  # Splits pitch_content ("subject\\n\\nbody") into subject + body.
  class PitchParser
    Result = Struct.new(:subject, :body, keyword_init: true)

    def self.call(pitch_content)
      new(pitch_content).call
    end

    def initialize(pitch_content)
      @pitch_content = pitch_content.to_s.strip
    end

    def call
      return Result.new(subject: nil, body: nil) if @pitch_content.blank?

      lines = @pitch_content.lines.map(&:rstrip)
      subject = lines.first.to_s.sub(/\Asubject:\s*/i, "").strip

      rest = lines.drop(1)
      rest.shift while rest.first&.strip&.empty?
      body = rest.join("\n").strip

      Result.new(subject: subject.presence, body: body.presence)
    end
  end
end
