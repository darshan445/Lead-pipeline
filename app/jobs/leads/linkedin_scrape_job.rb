module Leads
  class LinkedinScrapeJob < ApplicationJob
    queue_as :default

    ACTOR_ID = "kH7li2wTed8S3VaiV"

    # Accepts a single lead id or an array of ids.
    def perform(lead_ids)
      leads = Lead.where(id: Array(lead_ids)).to_a
      return if leads.empty?

      leads.each { |lead| lead.update!(status: :scraping) }
      by_slug = leads.index_by { |lead| slug_from(lead.profile_url) }

      results = ApifyClient.new.run_actor(
        ACTOR_ID,
        {
          companyUrls: leads.map(&:profile_url),
          maxCompanies: leads.size
        },
        timeout: 300
      )

      matched_ids = []
      results.each do |profile|
        slug = slug_from(profile["linkedinUrl"].presence || profile["url"].to_s)
        lead = by_slug[slug]
        next unless lead

        matched_ids << lead.id
        apply(lead, profile)
      end

      leads.each do |lead|
        next if matched_ids.include?(lead.id)
        lead.update!(status: :failed, error_message: "No profile returned by scraper")
      end
    rescue => e
      Array(leads).each { |lead| lead.update(status: :failed, error_message: e.message) }
    end

    private

    def apply(lead, profile)
      if profile["error"].present?
        lead.update!(status: :failed, error_message: profile["error"].to_s)
        return
      end

      website_url = extract_website(profile)
      lead.update!(raw_data: profile, website_url: website_url)
      Leads::LinkedinQualifyJob.perform_later(lead.id)
    end

    def slug_from(profile_url)
      URI.parse(profile_url.to_s).path.split("/").reject(&:blank?).last.to_s.downcase
    end

    def extract_website(profile)
      profile["website"].presence ||
        profile["websiteUrl"].presence ||
        profile.dig("callToAction", "url")
    end
  end
end
