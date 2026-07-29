class Agent < ApplicationRecord
  has_many :leads, dependent: :nullify

  has_rich_text :dm_instructions
  has_rich_text :email_instructions

  validates :name, presence: true

  # Plain-text instructions for the given pitch type, for use as LLM context.
  def instructions_for(pitch_type)
    rich_text = pitch_type.to_s == "dm" ? dm_instructions : email_instructions
    rich_text.body&.to_plain_text.to_s.strip
  end
end
