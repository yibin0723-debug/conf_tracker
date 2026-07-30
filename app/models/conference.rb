class Conference < ApplicationRecord
  has_many :bookmarks, dependent: :destroy
  has_many :users, through: :bookmarks

  has_many :conference_topics, dependent: :destroy
  has_many :topics, through: :conference_topics

  validates :name,
            :location,
            :starts_on,
            :ends_on,
            :submission_deadline,
            presence: true

  validates :website_url,
            format: {
              with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
              allow_blank: true
            }

  validates :rating,
            length: { maximum: 50 },
            allow_blank: true

  validate :ends_on_is_not_before_starts_on
  validate :submission_deadline_is_not_after_start_date

  def topic_names
    topics.order(:name).pluck(:name).join(", ")
  end

  def replace_topics!(raw_names)
    normalized_names =
      Array(raw_names)
        .flat_map { |value| value.to_s.split(",") }
        .map { |name| Topic.normalize_name_value(name) }
        .reject(&:blank?)
        .uniq { |name| name.downcase }

    topic_records = normalized_names.map do |name|
      Topic.find_or_create_normalized!(name)
    end

    self.topics = topic_records
  end

  private

  def ends_on_is_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?
    return unless ends_on < starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end

  def submission_deadline_is_not_after_start_date
    return if submission_deadline.blank? || starts_on.blank?
    return unless submission_deadline > starts_on

    errors.add(
      :submission_deadline,
      "must be on or before the conference start date"
    )
  end
end
