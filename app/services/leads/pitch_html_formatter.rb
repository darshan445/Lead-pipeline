module Leads
  # Turns plain-text pitch body into email/UI HTML.
  # Preserves paragraphs, bolds Darsh Thakor in the sign-off, and makes http(s) URLs clickable.
  class PitchHtmlFormatter
    URL_REGEX = %r{(?<!["'>])(https?://[^\s<]+)}i
    BOLD_REGEX = /\*\*(.+?)\*\*/m

    def self.call(body)
      new(body).call
    end

    def initialize(body)
      @body = body.to_s
    end

    def call
      text = normalize_signature_bold(@body)
      escaped = ERB::Util.html_escape(text)
      with_bold = escaped.gsub(BOLD_REGEX, '<strong>\1</strong>')
      with_links = with_bold.gsub(URL_REGEX) { |url| link_tag(url) }

      with_links.gsub(/\r\n?/, "\n").split(/\n{2,}/).map { |para|
        "<p>#{para.gsub("\n", "<br>")}</p>"
      }.join
    end

    private

    # Ensure sign-off name is bold even if markdown was omitted.
    def normalize_signature_bold(text)
      return text if text.include?("**Darsh Thakor**")

      # Upgrade old short sign-off, then bold full name.
      text = text.gsub(/(^|\n)Darsh T(\n|$)/, "\\1Darsh Thakor\\2")
      text.gsub(/(^|\n)(Darsh Thakor)(\n|$)/, "\\1**\\2**\\3")
    end

    def link_tag(url)
      trailing = url[/[.,;:!?)]+\z/].to_s
      href = trailing.empty? ? url : url.delete_suffix(trailing)
      %(<a href="#{href}" class="text-indigo-600 underline">#{href}</a>) + trailing
    end
  end
end
