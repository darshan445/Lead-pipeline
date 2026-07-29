module Leads
  class PitchGenerationJob < ApplicationJob
    queue_as :default

    def perform(lead_id)
      lead = Lead.find(lead_id)
      lead.update!(status: :pitching, pitch_type: :email)

      pitch_content = Leads::PitchGenerator.new(lead).call
      parsed = Leads::PitchParser.call(pitch_content)
      subject = Leads::PitchGenerator::FIXED_SUBJECT
      body = Leads::PitchBodyNormalizer.call(parsed.body.presence || pitch_content)

      lead.update!(
        pitch_content: "#{subject}\n\n#{body}",
        pitch_subject: subject,
        pitch_body: body,
        status: :pitched,
        error_message: nil
      )
    rescue => e
      lead&.update(status: :failed, error_message: e.message)
    end
  end
end
