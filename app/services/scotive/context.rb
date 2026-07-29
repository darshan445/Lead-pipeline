module Scotive
  # Static product context derived from https://scotive.com/ — used by every LLM step.
  module Context
    PRODUCT_NAME = "Scotive"
    PRODUCT_URL = "https://scotive.com"

    # What Scotive is, who it is for, and what makes it different.
    PRODUCT_BRIEF = <<~TEXT.freeze
      Scotive (#{PRODUCT_URL}) is invoice-chasing software that helps people get paid faster.

      What it does:
      - Tracks unpaid invoices from email and accounting tools
      - Reads client replies for payment promises, disputes, and "says paid" claims
      - Drafts warm, context-aware follow-up emails based on invoice state
      - Requires human-in-the-loop approval — nothing is ever auto-sent without a 1-click review
      - Surfaces a "needs you today" queue (past due, broken promises, replies)

      Integrations (today): Gmail and QuickBooks Online.
      Roadmap: Outlook / Microsoft 365, Zoho Books, FreshBooks.

      Who it is for (ICP — ideal customers):
      - Freelancers, boutique agencies, consultants, studios & creative teams
      - Professional services and small businesses that bill clients
      - Founders, ops leads, and finance/AR owners at those firms
      - Anyone who sends invoices and manually chases unpaid ones

      Who it is NOT for:
      - Large enterprise collections / heavy AR suites teams that want fully automated blast sequences
      - Companies that do not invoice clients (pure product SaaS with no client billing, recruiters-only shops, etc.)
      - Roles with no ownership of invoicing, collections, or client payment follow-up
        (e.g. junior specialists, pure creative ICs with no billing responsibility, students, job seekers)

      Key differentiator vs tools like Chaser or Upflow:
      Scotive watches the conversations and invoices you already have, drafts the next follow-up in context,
      and never sends without your approval — built for freelancers and small agencies, not enterprise AR automation.
    TEXT

    ICP_ROLES = <<~TEXT.freeze
      Best people to pitch inside a target company:
      - Founders, Co-founders, Owners, Partners
      - CEO, Managing Director
      - Head of Ops / Operations Manager / Agency Ops
      - Finance, Bookkeeper, AR / Accounts Receivable owners
      - Office managers or producers who own client billing in small studios

      Usually skip unless they clearly own billing/collections:
      - Junior PPC/SEO/design specialists, interns, pure ICs
      - Recruiters, HR-only, sales-only with no AR ownership
    TEXT
  end
end
