class GmailOauthController < ApplicationController
  def connect
    state = SecureRandom.hex(16)
    session[:gmail_oauth_state] = state
    redirect_to GmailClient.new.authorization_url(state: state), allow_other_host: true
  end

  def callback
    if params[:error].present?
      redirect_to leads_path, alert: "Gmail connect cancelled: #{params[:error]}" and return
    end

    if params[:state].blank? || params[:state] != session[:gmail_oauth_state]
      redirect_to leads_path, alert: "Gmail connect failed: invalid OAuth state." and return
    end

    tokens = GmailClient.new.exchange_code(params[:code])
    refresh_token = tokens["refresh_token"].to_s

    if refresh_token.blank?
      redirect_to leads_path,
        alert: "No refresh token returned. Revoke app access in Google Account → Security → Third-party access, then connect again." and return
    end

    persist_refresh_token!(refresh_token)
    session.delete(:gmail_oauth_state)

    redirect_to leads_path, notice: "Gmail connected for #{ENV.fetch('GMAIL_SENDER_EMAIL', 'darsh@getscotive.com')}. Refresh token saved to .env."
  rescue GmailClient::Error => e
    redirect_to leads_path, alert: e.message
  end

  private

  def persist_refresh_token!(refresh_token)
    ENV["GMAIL_REFRESH_TOKEN"] = refresh_token

    env_path = Rails.root.join(".env")
    return unless File.exist?(env_path)

    contents = File.read(env_path)
    if contents.match?(/^GMAIL_REFRESH_TOKEN=.*$/)
      contents = contents.sub(/^GMAIL_REFRESH_TOKEN=.*$/, "GMAIL_REFRESH_TOKEN=#{refresh_token}")
    else
      contents = contents.strip + "\nGMAIL_REFRESH_TOKEN=#{refresh_token}\n"
    end
    File.write(env_path, contents)
  end
end
