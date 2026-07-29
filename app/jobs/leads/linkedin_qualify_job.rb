module Leads
  # After LinkedIn scrape, ask the LLM if this company fits Scotive's ICP.
  # Qualified companies continue to employee discovery; others stop.
  class LinkedinQualifyJob < ApplicationJob
    queue_as :default

    def perform(lead_id)
      lead = Lead.find(lead_id)
      lead.update!(status: :qualifying)

      unless company_profile?(lead.profile_url)
        lead.update!(status: :rejected, error_message: "Not a LinkedIn company profile")
        return
      end

      result = Leads::CompanyQualifier.new(lead).call
      lead.update!(
        raw_data: lead.raw_data.merge(
          "qualification_analysis" => result.analysis
        )
      )

      if result.qualified
        lead.update!(status: :employee_discovery, error_message: nil)
        Leads::LinkedinEmployeesJob.perform_later(lead.id)
      else
        lead.update!(
          status: :rejected,
          error_message: result.reason.presence || "Not a Scotive ICP fit"
        )
      end
    rescue => e
      lead&.update(status: :failed, error_message: e.message)
    end

    private

    def company_profile?(profile_url)
      path = URI.parse(profile_url.to_s).path.to_s.downcase
      path.split("/").reject(&:blank?).first == "company"
    rescue URI::InvalidURIError
      false
    end
  end
end
