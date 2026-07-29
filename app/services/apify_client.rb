class ApifyClient
  class Error < StandardError; end

  BASE_URL = "https://api.apify.com"

  def initialize(token: ENV.fetch("APIFY_API_TOKEN"))
    @token = token
  end

  # Runs an actor synchronously and returns its dataset items as an Array of Hashes.
  def run_actor(actor_id, input, timeout: 120)
    response = connection.post("/v2/actors/#{actor_id}/run-sync-get-dataset-items") do |req|
      req.params["token"] = @token
      req.params["timeout"] = timeout
      req.options.timeout = timeout + 60
      req.body = input
    end

    unless response.success?
      raise Error, "Apify actor #{actor_id} failed: #{response.status} #{response.body}"
    end

    response.body.is_a?(Array) ? response.body : []
  rescue Faraday::Error => e
    raise Error, "Apify request to actor #{actor_id} failed: #{e.message}"
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.options.timeout = 180
      f.adapter Faraday.default_adapter
    end
  end
end
