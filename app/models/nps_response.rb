# == Schema Information
#
# Table name: nps_responses
#
#  id              :bigint           not null, primary key
#  comment         :text
#  score           :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :bigint           not null
#  conversation_id :bigint
#  inbox_id        :bigint
#
# Indexes
#
#  index_nps_responses_on_account_id_and_created_at  (account_id,created_at)
#  index_nps_responses_on_conversation_id            (conversation_id)
#
class NpsResponse < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true

  validates :score, presence: true, numericality: { only_integer: true, in: 0..10 }

  scope :promoters, -> { where(score: 9..10) }
  scope :passives,  -> { where(score: 7..8) }
  scope :detractors, -> { where(score: 0..6) }

  def category
    return 'promoter' if score >= 9
    return 'passive'  if score >= 7

    'detractor'
  end
end
