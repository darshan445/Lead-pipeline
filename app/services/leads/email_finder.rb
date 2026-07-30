module Leads
  # Looks up a person lead's email via Anymailfinder and stores it on the lead.
  class EmailFinder
    class Error < StandardError; end

    Result = Struct.new(:email, :status, :response, keyword_init: true)

    def self.call(lead)
      new(lead).call
    end

    def initialize(lead, client: AnymailfinderClient.new)
      @lead = lead
      @client = client
    end

    def call
      raise Error, "Email find is only for people leads." unless @lead.person_lead?

      full_name = person_full_name
      domain = company_domain
      linkedin_url = @lead.profile_url

      if full_name.blank? || full_name.split(/\s+/).size < 2
        raise Error, "Full name must include first and last name."
      end
      if domain.blank?
        raise Error, "Company domain is required to find an email."
      end

      response = @client.find_person_email(
        domain: domain,
        full_name: full_name,
        linkedin_url: linkedin_url
      )

      email = response["valid_email"].presence || response["email"].presence
      status = response["email_status"].to_s

      @lead.update!(
        email: email.presence || @lead.email,
        raw_data: @lead.raw_data.merge(
          "anymailfinder" => {
            "looked_up_at" => Time.current.iso8601,
            "domain" => domain,
            "full_name" => full_name,
            "response" => response
          }
        )
      )

      Result.new(email: email, status: status, response: response)
    end

    private

    def person_full_name
      data = @lead.raw_data || {}
      from_parts = [ data["firstName"], data["lastName"] ].map { |v| v.to_s.strip.presence }.compact.join(" ")
      from_parts.presence || @lead.profile_name.to_s.strip.presence
    end

    def company_domain
      url = @lead.website_url.presence || @lead.raw_data["companyWebsite"].presence
      return nil if url.blank?

      host = URI.parse(url.to_s.start_with?("http") ? url.to_s : "https://#{url}").host
      host.to_s.downcase.delete_prefix("www.").presence
    rescue URI::InvalidURIError
      nil
    end
  end
end
