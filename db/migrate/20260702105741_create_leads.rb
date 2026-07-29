class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.text :query, null: false
      t.string :source, null: false
      t.string :profile_url, null: false
      t.string :website_url
      t.string :email
      t.jsonb :raw_data, null: false, default: {}
      t.string :pitch_type
      t.text :pitch_content
      t.string :status, null: false, default: "discovered"
      t.text :error_message

      t.timestamps
    end

    add_index :leads, :profile_url, unique: true
    add_index :leads, :status
    add_index :leads, :source
  end
end
