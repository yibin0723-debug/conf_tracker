module Api
  class ConferencesController < ApplicationController
    allow_unauthenticated_access only: :index

    def index
      scope = Conference.all

      scope = apply_search(scope)
      scope = apply_location_filter(scope)
      scope = apply_topic_filter(scope)
      scope = apply_date_filters(scope)

      total = scope.count

      conferences =
        apply_sort(scope)
          .includes(:topics)
          .limit(200)
          .to_a

      conference_ids = conferences.map(&:id)

      bookmark_counts =
        Bookmark
          .where(conference_id: conference_ids)
          .group(:conference_id)
          .count

      bookmarked_ids =
        if current_user
          current_user
            .bookmarks
            .where(conference_id: conference_ids)
            .pluck(:conference_id)
            .to_h { |conference_id| [conference_id, true] }
        else
          {}
        end

      render json: {
        conferences: conferences.map do |conference|
          conference_payload(
            conference,
            bookmark_counts,
            bookmarked_ids
          )
        end,
        meta: {
          total: total,
          topics: Topic
            .order(Arel.sql("LOWER(name) ASC"))
            .pluck(:name)
        }
      }
    end

    private

    def apply_search(scope)
      query = params[:q].to_s.strip
      return scope if query.blank?

      escaped_query =
        ActiveRecord::Base.sanitize_sql_like(query)

      pattern = "%#{escaped_query}%"

      matching_ids =
        Conference
          .left_joins(:topics)
          .where(
            <<~SQL.squish,
              conferences.name ILIKE :pattern
              OR conferences.location ILIKE :pattern
              OR COALESCE(conferences.description, '') ILIKE :pattern
              OR topics.name ILIKE :pattern
            SQL
            pattern: pattern
          )
          .select(:id)

      scope.where(id: matching_ids)
    end

    def apply_location_filter(scope)
      location = params[:location].to_s.strip
      return scope if location.blank?

      escaped_location =
        ActiveRecord::Base.sanitize_sql_like(location)

      scope.where(
        "conferences.location ILIKE ?",
        "%#{escaped_location}%"
      )
    end

    def apply_topic_filter(scope)
      topic_name = params[:topic].to_s.strip
      return scope if topic_name.blank?

      matching_ids =
        Conference
          .joins(:topics)
          .where(
            "LOWER(topics.name) = ?",
            topic_name.downcase
          )
          .select(:id)

      scope.where(id: matching_ids)
    end

    def apply_date_filters(scope)
      date_from = parse_date(params[:date_from])
      date_to = parse_date(params[:date_to])

      scope = scope.where(
        "conferences.starts_on >= ?",
        date_from
      ) if date_from

      scope = scope.where(
        "conferences.starts_on <= ?",
        date_to
      ) if date_to

      scope
    end

    def apply_sort(scope)
      case params[:sort]
      when "date_desc"
        scope.order(
          starts_on: :desc,
          created_at: :desc
        )
      when "deadline_asc"
        scope.order(
          Arel.sql(
            "conferences.submission_deadline ASC NULLS LAST"
          ),
          starts_on: :asc
        )
      when "deadline_desc"
        scope.order(
          Arel.sql(
            "conferences.submission_deadline DESC NULLS LAST"
          ),
          starts_on: :asc
        )
      when "name_asc"
        scope.order(
          Arel.sql("LOWER(conferences.name) ASC")
        )
      else
        scope.order(
          starts_on: :asc,
          created_at: :desc
        )
      end
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def conference_payload(
      conference,
      bookmark_counts,
      bookmarked_ids
    )
      deadline = conference.submission_deadline

      {
        id: conference.id,
        name: conference.name,
        location: conference.location,
        starts_on: conference.starts_on,
        ends_on: conference.ends_on,
        submission_deadline: deadline,
        days_until_submission:
          deadline ? (deadline - Date.current).to_i : nil,
        rating: conference.rating,
        website_url: conference.website_url,
        description: conference.description,
        topics: conference
          .topics
          .map(&:name)
          .sort_by(&:downcase),
        duration_days:
          if conference.starts_on && conference.ends_on
            (conference.ends_on - conference.starts_on).to_i + 1
          end,
        bookmark_count:
          bookmark_counts.fetch(conference.id, 0),
        bookmarked:
          bookmarked_ids.key?(conference.id),
        detail_path:
          "/conferences/#{conference.id}"
      }
    end
  end
end
