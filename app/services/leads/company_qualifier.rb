module Leads
  # Decides whether a scraped LinkedIn company profile is a Scotive ICP fit.
  class CompanyQualifier
    Result = Struct.new(:qualified, :reason, :analysis, keyword_init: true)

    def initialize(lead, openrouter_client: OpenRouterClient.new)
      @lead = lead
      @openrouter_client = openrouter_client
    end

    def call
      content = @openrouter_client.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.1
      )
      parse_result(content)
    end

    private

    def system_prompt
      <<~PROMPT
        # Role

        You are a B2B sales qualification analyst.

        Your job is to determine whether a company is a strong potential customer for Scotive.

        Do NOT be optimistic.

        Do NOT assume.

        Be skeptical.

        Only approve companies that genuinely fit Scotive's ideal customer profile.

        If there is insufficient evidence, reject the company.

        ---

        # About Scotive

        Scotive helps businesses automate payment follow-ups after invoices have been sent.

        It does NOT create invoices.

        It does NOT replace QuickBooks, Xero, FreshBooks or accounting software.

        Instead it works alongside existing tools.

        Scotive helps businesses by:

        * Tracking due invoices
        * Tracking overdue invoices
        * Following up automatically
        * Understanding payment promises
        * Handling broken promises
        * Managing disputes
        * Tracking partial payments
        * Remembering when to follow up
        * Sending personalized follow-up emails using previous email conversations

        The biggest problem Scotive solves is:

        Businesses that invoice clients manually spend too much time chasing payments.

        ---

        # Ideal Customer Profile

        Strong matches include companies that:

        * Sell services
        * Invoice clients after work is completed
        * Have recurring client relationships
        * Work with many different clients
        * Have accounts receivable processes
        * Have finance or operations staff
        * Have project-based billing
        * Likely experience overdue invoices

        Examples:

        * Marketing agencies
        * Digital agencies
        * SEO agencies
        * Web development agencies
        * Design studios
        * Branding agencies
        * Video production companies
        * PR agencies
        * Recruiting agencies
        * Staffing firms
        * Consulting firms
        * Software agencies
        * IT service companies
        * Managed service providers
        * Engineering consultancies
        * Architecture firms
        * Creative studios
        * Professional services firms
        * Accounting firms
        * Bookkeeping firms
        * Legal firms (small to medium)

        ---

        # Usually Good

        These are generally good unless evidence suggests otherwise:

        * Agency
        * Studio
        * Consultancy
        * Professional services
        * Client services
        * Outsourcing company
        * B2B service provider

        ---

        # Weak Matches

        These may qualify only if there is strong evidence they invoice many clients.

        Examples:

        * SaaS companies
        * Product companies
        * Ecommerce
        * Manufacturers
        * Healthcare providers
        * Education companies

        ---

        # Reject Immediately

        Reject if the company is primarily:

        * Consumer brand
        * Retail store
        * Restaurant
        * Hotel
        * Nonprofit
        * Government
        * School
        * University
        * Cryptocurrency project
        * Community
        * Open source project
        * Media publication
        * Marketplace
        * Venture capital firm
        * Investment fund
        * Holding company
        * Internal IT department
        * Freelancer (unless operating a growing agency)
        * Personal brand
        * Influencer business

        ---

        # Research Rules

        Use only publicly available information.

        Prefer evidence from:

        * Company website
        * About page
        * Services page
        * LinkedIn Company page
        * Careers page

        Do NOT guess.

        If evidence is weak, reject.

        ---

        # Qualification Criteria

        Evaluate:

        1. Does the company sell services?
        2. Does it likely invoice customers?
        3. Does it likely have multiple invoices outstanding at any time?
        4. Would payment follow-up probably be manual today?
        5. Does Scotive clearly solve a problem for them?

        ---

        # Scoring

        Score each category from 0–5.

        * Service Business
        * Client Billing Complexity
        * Likelihood of Manual Payment Follow-up
        * Number of Clients
        * Overall ICP Fit

        ---

        # Decision Rules

        APPROVE only if:

        * Overall ICP Fit >= 4
        * AND there is clear evidence they invoice clients.
        * AND Scotive would obviously save time.

        Otherwise reject.

        If uncertain:

        REJECT.

        ---

        # Output Format

        Company:
        Website:

        Industry:

        Business Model:

        Evidence:

        Why they are (or are not) a good Scotive customer:

        Scores:

        * Service Business:
        * Billing Complexity:
        * Manual Follow-up Likelihood:
        * Client Volume:
        * ICP Fit:

        Decision:

        ✅ APPROVE

        or

        ❌ REJECT

        Confidence:

        High / Medium / Low

        Final one-line reason:

        Reason for Rejection:

        Outreach Angle:

        Return only the filled output above. No code fences. No JSON.
      PROMPT
    end

    def user_prompt
      data = @lead.raw_data || {}
      summary = data.slice(
        "companyName", "name", "universalName", "tagline", "description",
        "industry", "industries", "specialities", "specialties",
        "staffCount", "employeeCount", "companySize", "companyType",
        "website", "websiteUrl", "linkedinUrl",
        "followerCount", "headquarter", "headquarters", "city", "state", "country", "type"
      )

      <<~PROMPT
        LinkedIn URL: #{@lead.profile_url}
        Website: #{@lead.website_url}

        Company profile data (JSON):
        #{summary.to_json}
      PROMPT
    end

    def parse_result(content)
      text = content.to_s.strip
      approved = text.match?(/^\s*Decision:\s*(?:\n\s*)?✅\s*APPROVE\b/im) || text.match?(/✅\s*APPROVE/i)
      rejected = text.match?(/^\s*Decision:\s*(?:\n\s*)?❌\s*REJECT\b/im) || text.match?(/❌\s*REJECT/i)

      reason =
        extract_field(text, "Final one-line reason") ||
        extract_field(text, "Reason for Rejection") ||
        default_reason(approved, rejected)

      Result.new(
        qualified: approved && !rejected,
        reason: reason,
        analysis: text
      )
    end

    def extract_field(text, label)
      pattern = /
        ^#{Regexp.escape(label)}:\s*
        (.+?)
        (?=\n[A-Z][A-Za-z \-]+:|\n\* |\z)
      /mix

      text[pattern, 1]&.strip
    end

    def default_reason(approved, rejected)
      return "Approved by qualifier" if approved
      return "Rejected by qualifier" if rejected

      "Could not determine qualification outcome"
    end
  end
end
