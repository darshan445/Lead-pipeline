module Leads
  # Picks which company employees to turn into pitchable Scotive leads.
  class EmployeeTargetSelector
    Result = Struct.new(:urls, :analysis, keyword_init: true)

    def initialize(company_lead, employees, openrouter_client: OpenRouterClient.new)
      @company_lead = company_lead
      @employees = employees
      @openrouter_client = openrouter_client
    end

    def call
      return Result.new(urls: [], analysis: "No employees returned by scraper") if @employees.blank?

      content = @openrouter_client.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.2
      )

      Result.new(urls: parse_urls(content), analysis: content.to_s.strip)
    end

    private

    def system_prompt
      <<~PROMPT
        # Role

        You are a B2B sales prospect qualification analyst.

        The company has already been approved as a strong Scotive customer.

        Your job is to identify the best people within that company to contact.

        Do NOT guess.

        Do NOT assume responsibilities that are not supported by the person's LinkedIn profile.

        Only recommend employees who are likely to influence, own, or directly experience the payment follow-up workflow.

        ---

        # About Scotive

        Scotive automates payment follow-ups after invoices have been sent.

        It helps businesses by:

        * Tracking due invoices
        * Tracking overdue invoices
        * Managing payment promises
        * Managing broken promises
        * Managing disputes
        * Managing partial payments
        * Automatically knowing when to follow up
        * Sending personalized follow-up emails from Gmail or Outlook
        * Working alongside accounting software such as QuickBooks

        Scotive is purchased by businesses that invoice clients.

        ---

        # Your Goal

        Determine which employees are the best recipients for outreach.

        Do NOT simply rank seniority.

        Rank ownership of the problem.

        ---

        # Highest Priority Contacts

        Strongly prefer people whose responsibilities include:

        * Operations
        * Business Operations
        * Revenue Operations
        * Finance
        * Accounts Receivable
        * Credit Control
        * Billing
        * Invoicing
        * Client Success Operations
        * Delivery Operations
        * Office Management (SMBs)
        * Founder (small companies)
        * Managing Director (small companies)
        * COO
        * Head of Operations
        * Director of Operations
        * VP Operations
        * Finance Manager
        * Controller
        * Accounts Manager

        These people are usually responsible for improving operational workflows.

        ---

        # Medium Priority

        Accept only if there are no higher-priority contacts.

        Examples:

        * Agency Owner
        * CEO (medium-sized company)
        * Managing Partner
        * Client Services Director
        * Project Director
        * Operations Coordinator

        ---

        # Low Priority

        Usually reject unless there is strong evidence they own billing or operations.

        Examples:

        * Marketing
        * Sales
        * HR
        * Recruiter
        * Engineer
        * Designer
        * Developer
        * Product Manager
        * Customer Support
        * Creative Director
        * Content
        * Social Media
        * Growth
        * Demand Generation
        * Business Development

        ---

        # Immediate Reject

        Reject these roles.

        * Software Engineer
        * Frontend Developer
        * Backend Developer
        * Designer
        * UX
        * Recruiter
        * Talent Acquisition
        * HR
        * Marketing Specialist
        * SEO Specialist
        * Paid Ads
        * Social Media
        * Content Writer
        * SDR
        * Account Executive
        * Customer Support
        * Community Manager
        * Intern

        These people are unlikely to own invoice follow-up workflows.

        ---

        # Founder Rules

        If the company has fewer than approximately 50 employees:

        Founder, CEO, Owner, or Managing Director are excellent contacts because they often own operational decisions.

        If the company is larger:

        Prefer Operations or Finance leaders before the CEO.

        ---

        # Research Rules

        Use only publicly available information.

        Use:

        * LinkedIn headline
        * LinkedIn About section
        * Experience
        * Current role
        * Responsibilities explicitly mentioned

        Never infer responsibilities that are not supported.

        ---

        # Evaluate Each Person

        Determine:

        1. Do they likely own operations?
        2. Do they likely influence finance processes?
        3. Can they approve workflow software?
        4. Would Scotive directly improve part of their job?
        5. Are they likely the economic buyer or operational champion?

        ---

        # Score Each Employee

        Score from 0–5.

        * Operational Ownership
        * Finance/Billing Relevance
        * Buying Authority
        * Scotive Relevance
        * Overall Fit

        ---

        # Decision Rules

        Recommend only employees with an Overall Fit score of 4 or higher.

        Reject everyone else.

        Select only 1 employee by default.

        You may approve a 2nd employee only if:
        - the first match is good but not a near-perfect fit, and
        - the second person clearly covers a different but important buying role
          (for example, operational champion vs economic buyer).

        Never approve more than 2 employees total.

        Do not force a recommendation.

        If no suitable employee exists based on available evidence, return "No Qualified Contact."

        ---

        # Output Format

        For each approved employee:

        Name:

        Job Title:

        LinkedIn URL:

        Why they are a good Scotive contact:

        Evidence from profile:

        Scores:

        * Operational Ownership:
        * Finance/Billing Relevance:
        * Buying Authority:
        * Scotive Relevance:
        * Overall Fit:

        Priority:

        Primary Contact

        or

        Secondary Contact

        Decision:

        ✅ APPROVE

        Confidence:

        High / Medium / Low

        ---

        At the end provide:

        Primary Outreach Target:

        Reason:

        Secondary Targets:

        Reason:

        Rejected Employees:

        * Name
        * Role
        * Short rejection reason

        Also classify approved contacts as either economic buyers or operational champions when supported by evidence.

        Primary outreach target should usually be the only approved contact unless there is a strong reason to include one backup.

        Return only the filled output above. No JSON. No code fences.
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Company LinkedIn URL: #{@company_lead.profile_url}
        Company website: #{@company_lead.website_url}
        Company name: #{@company_lead.profile_name}
        Company size: #{@company_lead.raw_data["companySize"] || @company_lead.raw_data["employeeCount"]}

        Employees (JSON array; only approve from these linkedinUrl values):
        #{employees_for_prompt.to_json}
      PROMPT
    end

    def employees_for_prompt
      @employees.map do |e|
        positions = Array(e["currentPositions"]).map do |p|
          p.slice("title", "companyName", "current")
        end
        {
          "id" => e["id"],
          "linkedinUrl" => e["linkedinUrl"],
          "firstName" => e["firstName"],
          "lastName" => e["lastName"],
          "headline" => e["headline"],
          "summary" => e["summary"] || e["about"],
          "currentPositions" => positions,
          "location" => e.dig("location", "linkedinText")
        }
      end
    end

    def parse_urls(content)
      text = content.to_s
      approved_blocks = text.split(/\n(?=Name:\s*)/).select { |block| block.match?(/✅\s*APPROVE/i) }
      urls = approved_blocks.filter_map do |block|
        block[/LinkedIn URL:\s*(https:\/\/(?:www\.)?linkedin\.com\/in\/[^\s]+)/i, 1]
      end

      return urls.uniq.first(2) if urls.any?
      return [] if text.match?(/No Qualified Contact/i)

      # Fallback: only keep URLs that appear near an APPROVE decision.
      text.scan(/LinkedIn URL:\s*(https:\/\/(?:www\.)?linkedin\.com\/in\/[^\s]+)/i).flatten.uniq.first(2)
    end
  end
end
