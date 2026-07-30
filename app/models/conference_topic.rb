class ConferenceTopic < ApplicationRecord
  belongs_to :conference
  belongs_to :topic

  validates :topic_id,
            uniqueness: {
              scope: :conference_id,
              message: "has already been assigned to this conference"
            }
end
