module Leads
  # Runs apify/google-search-scraper with the exact input payload we use in production
  # and returns the dataset items (one item per query/page, organic results under "organicResults").
  class GoogleSearch
    ACTOR_ID = "apify~google-search-scraper"
    MAX_PAGES = 10 # Google serves at most ~1000 results: 10 pages x 100 per page

    def self.call(query, max_pages: 1)
      ApifyClient.new.run_actor(ACTOR_ID, input_for(query, max_pages), timeout: 300)
    end

    def self.input_for(query, max_pages = 1)
      {
        queries: query,
        resultsPerPage: 100,
        maxPagesPerQuery: max_pages,
        focusOnPaidAds: false,
        forceExactMatch: false,
        includeIcons: false,
        includeUnfilteredResults: false,
        mobileResults: false,
        saveHtml: false,
        saveHtmlToKeyValueStore: true,
        maximumLeadsEnrichmentRecords: 0,
        verifyLeadsEnrichmentEmails: false,
        chatGptSearch: { enableChatGpt: false },
        copilotSearch: { enableCopilot: false },
        geminiSearch: { enableGemini: false },
        perplexitySearch: {
          enablePerplexity: false,
          returnImages: false,
          returnRelatedQuestions: false
        }
      }
    end

    # Flattens dataset items into organic result hashes (title/url/description/...).
    def self.organic_results(items)
      items.flat_map { |page| page["organicResults"] || [] }
    end
  end
end
