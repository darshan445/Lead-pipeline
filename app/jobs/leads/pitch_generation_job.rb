module Leads
  class PitchGenerationJob < ApplicationJob
    queue_as :default

    def perform(lead_id, personalization: nil)
      lead = Lead.find(lead_id)
      lead.update!(status: :pitching, pitch_type: :email)

      generator = Leads::PitchGenerator.new(lead, personalization: personalization)
      pitch_content = generator.call
      parsed = Leads::PitchParser.call(pitch_content)
      subject = parsed.subject.presence || Leads::PitchGenerator::FIXED_SUBJECT
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
