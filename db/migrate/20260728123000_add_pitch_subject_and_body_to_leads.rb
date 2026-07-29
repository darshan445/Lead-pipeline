class AddPitchSubjectAndBodyToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :pitch_subject, :string
    add_column :leads, :pitch_body, :text
  end
end
