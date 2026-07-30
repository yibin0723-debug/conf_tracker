class Topic < ApplicationRecord
  has_many :conference_topics, dependent: :destroy
  has_many :conferences, through: :conference_topics

  before_validation :normalize_name

  validates :name,
            presence: true,
            length: { maximum: 80 },
            uniqueness: { case_sensitive: false }

  def self.find_or_create_normalized!(raw_name)
    normalized_name = normalize_name_value(raw_name)

    find_by("LOWER(name) = ?", normalized_name.downcase) ||
      create!(name: normalized_name)
  end

  def self.normalize_name_value(value)
    value.to_s.strip.gsub(/\s+/, " ")
  end

  private

  def normalize_name
    self.name = self.class.normalize_name_value(name)
  end
end
