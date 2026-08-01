module Leads
  # Re-enqueues the pipeline step a lead stalled on. Shared by single and bulk retry.
  class RetryRunner
    Result = Struct.new(:retried, :stage, :message, keyword_init: true) do
      def retried?
        retried
      end
    end

    def self.call(lead)
      new(lead).call
    end

    def initialize(lead)
      @lead = lead
    end

    def call
      return failure("#{@lead.profile_name} is not retryable.") unless @lead.retryable?

      case @lead.retry_stage
      when :scrape
        Leads::LinkedinScrapeJob.perform_later([ @lead.id ])
        success(:scrape, "Retrying company scrape for #{@lead.profile_name}...")
      when :qualify
        @lead.update!(status: :qualifying, error_message: nil)
        Leads::LinkedinQualifyJob.perform_later(@lead.id)
        success(:qualify, "Retrying company qualification for #{@lead.profile_name}...")
      when :employee_select
        @lead.update!(status: :employee_discovery, error_message: nil)
        Leads::LinkedinEmployeesJob.perform_later(@lead.id)
        success(:employee_select, "Retrying employee discovery for #{@lead.profile_name}...")
      when :pitch
        Leads::PitchGenerationJob.perform_later(@lead.id)
        success(:pitch, "Retrying pitch generation for #{@lead.profile_name}...")
      when :send
        Leads::GmailSendJob.perform_later(@lead.id)
        success(:send, "Retrying Gmail send for #{@lead.profile_name}...")
      else
        failure("Could not determine which step to retry for #{@lead.profile_name}.")
      end
    end

    private

    def success(stage, message)
      Result.new(retried: true, stage: stage, message: message)
    end

    def failure(message)
      Result.new(retried: false, stage: nil, message: message)
    end
  end
end
