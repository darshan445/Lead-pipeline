module Leads
  class GmailSendJob < ApplicationJob
    queue_as :default

    def perform(lead_id)
      Leads::GmailSender.call(lead_id)
    end
  end
end
