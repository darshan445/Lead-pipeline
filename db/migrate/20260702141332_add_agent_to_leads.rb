class AddAgentToLeads < ActiveRecord::Migration[8.0]
  def change
    # Nullable: leads created before agents existed have no agent.
    add_reference :leads, :agent, null: true, foreign_key: true
  end
end
