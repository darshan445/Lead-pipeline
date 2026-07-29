class GmailClient
  class Error < StandardError; end

  TOKEN_URL = "https://oauth2.googleapis.com/token"
  SEND_URL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"
  AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
  SCOPE = "https://www.googleapis.com/auth/gmail.send"

  def initialize(
    client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
    client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
    refresh_token: ENV["GMAIL_REFRESH_TOKEN"],
    redirect_uri: ENV.fetch("GMAIL_REDIRECT_URI", "http://localhost:3000/gmail/oauth/callback"),
    sender_email: ENV.fetch("GMAIL_SENDER_EMAIL", "darsh@getscotive.com"),
    sender_name: ENV.fetch("GMAIL_SENDER_NAME", "Darsh Thakor")
  )
    @client_id = client_id
    @client_secret = client_secret
    @refresh_token = refresh_token
    @redirect_uri = redirect_uri
    @sender_email = sender_name.present? ? "#{sender_name} <#{sender_email}>" : sender_email
    @from_email = sender_email
  end

  def self.configured?
    ENV["GOOGLE_CLIENT_ID"].present? &&
      ENV["GOOGLE_CLIENT_SECRET"].present? &&
      ENV["GMAIL_REFRESH_TOKEN"].present?
  end

  def authorization_url(state:)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      response_type: "code",
      scope: SCOPE,
      access_type: "offline",
      prompt: "consent",
      login_hint: @from_email,
      state: state
    }
    "#{AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  def exchange_code(code)
    response = Faraday.post(TOKEN_URL) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        code: code,
        client_id: @client_id,
        client_secret: @client_secret,
        redirect_uri: @redirect_uri,
        grant_type: "authorization_code"
      )
    end

    body = parse_json(response.body)
    unless response.success?
      raise Error, "Gmail OAuth token exchange failed: #{body}"
    end

    body
  rescue Faraday::Error => e
    raise Error, "Gmail OAuth request failed: #{e.message}"
  end

  def send_email(to:, subject:, text_body:, html_body:)
    raise Error, "GMAIL_REFRESH_TOKEN is missing. Connect Gmail first." if @refresh_token.blank?

    raw = build_raw_message(to: to, subject: subject, text_body: text_body, html_body: html_body)
    response = Faraday.post(SEND_URL) do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      req.headers["Content-Type"] = "application/json"
      req.body = { raw: raw }.to_json
    end

    body = parse_json(response.body)
    unless response.success?
      raise Error, "Gmail send failed: #{response.status} #{body.to_s.truncate(400)}"
    end

    body
  rescue Faraday::Error => e
    raise Error, "Gmail send request failed: #{e.message}"
  end

  private

  def access_token
    response = Faraday.post(TOKEN_URL) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        client_id: @client_id,
        client_secret: @client_secret,
        refresh_token: @refresh_token,
        grant_type: "refresh_token"
      )
    end

    body = parse_json(response.body)
    unless response.success? && body["access_token"].present?
      raise Error, "Gmail access token refresh failed: #{body}"
    end

    body["access_token"]
  rescue Faraday::Error => e
    raise Error, "Gmail token refresh failed: #{e.message}"
  end

  def build_raw_message(to:, subject:, text_body:, html_body:)
    boundary = "scotive_#{SecureRandom.hex(12)}"
    message = <<~MIME
      From: #{@sender_email}
      To: #{to}
      Subject: #{encode_subject(subject)}
      MIME-Version: 1.0
      Content-Type: multipart/alternative; boundary="#{boundary}"

      --#{boundary}
      Content-Type: text/plain; charset="UTF-8"
      Content-Transfer-Encoding: 7bit

      #{text_body}

      --#{boundary}
      Content-Type: text/html; charset="UTF-8"
      Content-Transfer-Encoding: 7bit

      #{html_body}

      --#{boundary}--
    MIME

    Base64.urlsafe_encode64(message, padding: false)
  end

  def encode_subject(subject)
    # RFC 2047 encoded-word for non-ASCII subjects.
    "=?UTF-8?B?#{Base64.strict_encode64(subject.to_s)}?="
  end

  def parse_json(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    { "raw" => body.to_s }
  end
end
