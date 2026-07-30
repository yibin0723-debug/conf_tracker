module Api
  module Admin
    class ConferencesController < ApplicationController
      before_action :require_admin!
      before_action :set_conference, only: %i[update destroy]

      def index
        conferences =
          Conference
            .includes(:topics)
            .order(starts_on: :asc, created_at: :desc)

        render json: {
          conferences: conferences.map do |conference|
            conference_payload(conference)
          end
        }
      end

      def create
        conference = Conference.new

        if save_conference_with_topics(conference)
          render json: {
            conference: conference_payload(conference)
          }, status: :created
        else
          render json: {
            errors: conference.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update
        if save_conference_with_topics(@conference)
          render json: {
            conference: conference_payload(@conference)
          }
        else
          render json: {
            errors: @conference.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def destroy
        @conference.destroy!
        head :no_content
      end

      private

      def set_conference
        @conference = Conference.find(params[:id])
      end

      def conference_params
        params.require(:conference).permit(
          :name,
          :location,
          :starts_on,
          :ends_on,
          :submission_deadline,
          :rating,
          :website_url,
          :description,
          :topic_names
        )
      end

      def conference_attributes
        conference_params.except(:topic_names)
      end

      def save_conference_with_topics(conference)
        Conference.transaction do
          conference.update!(conference_attributes)
          conference.replace_topics!(conference_params[:topic_names])
        end

        true
      rescue ActiveRecord::RecordInvalid => error
        unless error.record.equal?(conference)
          conference.errors.add(
            :topics,
            error.record.errors.full_messages.to_sentence
          )
        end

        false
      end

      def require_admin!
        return if current_user&.admin?

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def conference_payload(conference)
        {
          id: conference.id,
          name: conference.name,
          location: conference.location,
          starts_on: conference.starts_on,
          ends_on: conference.ends_on,
          submission_deadline: conference.submission_deadline,
          rating: conference.rating,
          website_url: conference.website_url,
          description: conference.description,
          topics: conference.topics.order(:name).pluck(:name),
          topic_names: conference.topic_names,
          created_at: conference.created_at
        }
      end
    end
  end
end
