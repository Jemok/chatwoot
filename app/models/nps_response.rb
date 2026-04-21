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
