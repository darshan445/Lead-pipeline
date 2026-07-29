module Leads
  class DiscoveryJob < ApplicationJob
    queue_as :default

    SCRAPE_BATCH_SIZE = 100
    MAX_RESULTS = 1000
    SOURCE = "linkedin"

    # query, max_results — LinkedIn company discovery only (Scotive pipeline).
    def perform(query, max_results = MAX_RESULTS, _agent_id = nil)
      max_results = max_results.to_i.clamp(1, MAX_RESULTS)
      urls = discover_company_urls(query, max_results)

      lead_ids = urls.filter_map do |url|
        lead = Lead.find_or_create_by(profile_url: url) do |l|
          l.query = query
          l.source = SOURCE
        end

        lead.id if lead.persisted? && lead.discovered?
      end

      lead_ids.each_slice(SCRAPE_BATCH_SIZE) do |batch|
        Leads::LinkedinScrapeJob.perform_later(batch)
      end
    end

    private

    # Google SERPs do not reliably yield 100 usable company URLs per page in practice,
    # so fetch incrementally until we hit the requested count or run out of pages.
    def discover_company_urls(query, max_results)
      urls = []

      1.upto(Leads::GoogleSearch::MAX_PAGES) do |page_limit|
        items = Leads::GoogleSearch.call(query, max_pages: page_limit)
        urls = extract_company_urls(items)
        break if urls.size >= max_results
      end

      urls.first(max_results)
    end

    def extract_company_urls(items)
      Leads::GoogleSearch.organic_results(items)
        .filter_map { |result| canonicalize_company(result["url"]) }
        .uniq
    end

    # Only LinkedIn company pages — person /in/ URLs are created later from employees.
    def canonicalize_company(url)
      uri = URI.parse(url.to_s)
      host = uri.host.to_s.downcase
      return nil unless host == "linkedin.com" || host.end_with?(".linkedin.com")

      segments = uri.path.to_s.split("/").reject(&:blank?)
      kind, slug = segments.first(2)
      return nil unless kind&.downcase == "company" && slug.present?

      "https://www.linkedin.com/company/#{slug.downcase}"
    rescue URI::InvalidURIError
      nil
    end
  end
end
