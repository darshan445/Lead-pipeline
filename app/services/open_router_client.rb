class OpenRouterClient
  class Error < StandardError; end

  BASE_URL = "https://openrouter.ai"
  DEFAULT_MODEL = "google/gemini-2.5-flash"

  def initialize(api_key: ENV.fetch("OPENROUTER_API_KEY"))
    @api_key = api_key
  end

  def chat(messages:, model: DEFAULT_MODEL, temperature: 0.7)
    response = connection.post("/api/v1/chat/completions") do |req|
      req.headers["Authorization"] = "Bearer #{@api_key}"
      req.body = { model: model, messages: messages, temperature: temperature }
    end

    unless response.success? && response.body.is_a?(Hash)
      raise Error, "OpenRouter request failed: #{response.status} #{response.body.to_s.truncate(300)}"
    end

    response.body.dig("choices", 0, "message", "content").to_s.strip
  rescue Faraday::Error => e
    raise Error, "OpenRouter request failed: #{e.message}"
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.options.timeout = 120
      f.adapter Faraday.default_adapter
    end
  end
end
