class AnymailfinderClient
  class Error < StandardError; end

  BASE_URL = "https://api.anymailfinder.com"
  FIND_PERSON_PATH = "/v5.1/find-email/person"

  def initialize(api_key: ENV.fetch("ANYMAILFINDER_API_KEY"))
    @api_key = api_key
  end

  # Finds a person email. Returns the parsed JSON body (Hash).
  def find_person_email(domain:, full_name:, linkedin_url:)
    response = connection.post(FIND_PERSON_PATH) do |req|
      req.headers["Authorization"] = @api_key
      req.body = {
        domain: domain,
        full_name: full_name,
        linkedin_url: linkedin_url
      }
    end

    body = parse_body(response.body)

    if response.status == 400
      raise Error, body["message"].presence || body["error"].presence || "Anymailfinder bad request"
    end

    unless response.success?
      raise Error, "Anymailfinder failed: #{response.status} #{body.to_s.truncate(300)}"
    end

    body
  rescue Faraday::Error => e
    raise Error, "Anymailfinder request failed: #{e.message}"
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.options.timeout = 60
      f.adapter Faraday.default_adapter
    end
  end

  def parse_body(body)
    body.is_a?(Hash) ? body : { "raw" => body.to_s }
  end
end
