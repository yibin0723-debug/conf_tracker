require "test_helper"

class ApiConferencesFilterTest < ActionDispatch::IntegrationTest
  setup do
    @conference = conferences(:one)

    @topic = Topic.create!(
      name: "Unique API Filter Topic"
    )

    @conference.topics << @topic
  end

  test "public API filters conferences by exact topic" do
    get "/api/conferences", params: {
      topic: @topic.name
    }

    assert_response :success

    body = JSON.parse(response.body)
    conferences = body.fetch("conferences")

    assert_equal [@conference.id],
                 conferences.map { |item| item.fetch("id") }

    result = conferences.first

    assert_equal @conference.submission_deadline.to_s,
                 result.fetch("submission_deadline")

    assert_equal @conference.rating,
                 result.fetch("rating")

    assert_includes result.fetch("topics"),
                    @topic.name

    assert_includes body.dig("meta", "topics"),
                    @topic.name
  end

  test "public API searches topic names" do
    get "/api/conferences", params: {
      q: "Unique API Filter"
    }

    assert_response :success

    body = JSON.parse(response.body)
    conference_ids =
      body.fetch("conferences").map do |item|
        item.fetch("id")
      end

    assert_includes conference_ids, @conference.id
  end
end
