class ConferencesController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_conference, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create edit update destroy]

  def index
    @conferences =
      Conference
        .includes(:topics)
        .order(starts_on: :asc, created_at: :desc)

    @bookmarks_by_conference_id =
      current_user
        &.bookmarks
        &.where(conference_id: @conferences.map(&:id))
        &.index_by(&:conference_id) || {}
  end

  def show
    @bookmark =
      current_user&.bookmarks&.find_by(conference: @conference)
  end

  def new
    @conference = Conference.new
  end

  def create
    @conference = Conference.new

    if save_conference_with_topics(@conference)
      redirect_to @conference,
                  notice: "Conference created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if save_conference_with_topics(@conference)
      redirect_to @conference,
                  notice: "Conference updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @conference.destroy!
    redirect_to conferences_path, notice: "Conference removed."
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

    redirect_to conferences_path,
                alert: "You are not authorized to perform this action."
  end
end
