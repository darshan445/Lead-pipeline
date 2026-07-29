module Leads
  # After a company passes Scotive ICP qualification, fetch employees and create person leads.
  class LinkedinEmployeesJob < ApplicationJob
    queue_as :default

    ACTOR_ID = "Vb6LZkh4EqRlR0Ka9" # harvestapi/linkedin-company-employees
    PROFILE_SCRAPER_MODE = "Short ($4 per 1k)"
    MAX_EMPLOYEES = 20

    def perform(company_lead_id)
      company_lead = Lead.find(company_lead_id)
      company_lead.update!(status: :employee_discovery)

      employees = fetch_employees(company_lead.profile_url)
      company_lead.update!(
        raw_data: company_lead.raw_data.merge("employees" => employees)
      )

      if employees.empty?
        company_lead.update!(status: :ready, error_message: "No employees returned by scraper")
        return
      end

      selection = Leads::EmployeeTargetSelector.new(company_lead, employees).call
      create_person_leads(company_lead, employees, selection.urls)

      company_lead.update!(
        status: :ready,
        error_message: nil,
        raw_data: company_lead.raw_data.merge(
          "employees" => employees,
          "selected_employee_urls" => selection.urls,
          "employee_selection_analysis" => selection.analysis
        )
      )
    rescue => e
      company_lead&.update(status: :failed, error_message: e.message)
    end

    private

    def fetch_employees(company_url)
      items = ApifyClient.new.run_actor(
        ACTOR_ID,
        {
          companies: [ company_url ],
          maxItems: MAX_EMPLOYEES,
          profileScraperMode: PROFILE_SCRAPER_MODE
        },
        timeout: 300
      )
      Array(items).first(MAX_EMPLOYEES)
    end

    def create_person_leads(company_lead, employees, selected_urls)
      selected_set = selected_urls.map { |u| canonicalize_profile_url(u) }.compact.to_set
      return if selected_set.empty?

      employees.each do |employee|
        url = canonicalize_profile_url(employee["linkedinUrl"])
        next if url.blank? || !selected_set.include?(url)

        lead = Lead.find_or_initialize_by(profile_url: url)
        next if lead.persisted? && !lead.discovered?

        lead.assign_attributes(
          query: company_lead.query,
          source: :linkedin,
          website_url: company_lead.website_url,
          raw_data: employee.merge(
            "companyProfileUrl" => company_lead.profile_url,
            "companyName" => company_lead.profile_name,
            "companyWebsite" => company_lead.website_url
          ),
          status: :ready,
          error_message: nil
        )
        lead.save!
      end
    end

    def canonicalize_profile_url(url)
      uri = URI.parse(url.to_s)
      host = uri.host.to_s.downcase
      return nil unless host == "linkedin.com" || host.end_with?(".linkedin.com")

      segments = uri.path.to_s.split("/").reject(&:blank?)
      kind, slug = segments.first(2)
      return nil unless kind&.downcase == "in" && slug.present?

      "https://www.linkedin.com/in/#{slug}"
    rescue URI::InvalidURIError
      nil
    end
  end
end
