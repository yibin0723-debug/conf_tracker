require "test_helper"

class ConferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @conference = conferences(:one)
    @admin = users(:two)
    @user = users(:one)
  end

  test "index is public" do
    get conferences_path
    assert_response :success
  end

  test "show is public" do
    get conference_path(@conference)
    assert_response :success
  end

  test "non-admin cannot access new" do
    sign_in_as(@user)

    get new_conference_path
    assert_redirected_to conferences_path
  end

  test "admin can create conference" do
    sign_in_as(@admin)

    assert_difference("Conference.count", 1) do
      post conferences_path, params: {
        conference: {
          submission_deadline: Date.new(2026, 10, 17),
          name: "Neuroscience Symposium",
          location: "Boston",
          starts_on: Date.new(2027, 1, 15),
          ends_on: Date.new(2027, 1, 17),
          website_url: "https://example.org/neuro",
          description: "A conference about neuroscience and computation."
        }
      }
    end

    assert_redirected_to conference_path(Conference.order(:id).last)
  end

  test "admin can update conference" do
    sign_in_as(@admin)

    patch conference_path(@conference), params: {
      conference: { 
        location: "Munich",
        submission_deadline: Date.new(2000, 1, 1)
      }
    }

    assert_redirected_to conference_path(@conference)
    assert_equal "Munich", @conference.reload.location
  end

  test "admin can destroy conference" do
    sign_in_as(@admin)

    assert_difference("Conference.count", -1) do
      delete conference_path(@conference)
    end

    assert_redirected_to conferences_path
  end

  test "non-admin cannot destroy conference" do
    sign_in_as(@user)

    assert_no_difference("Conference.count") do
      delete conference_path(@conference)
    end

    assert_redirected_to conferences_path
  end
end
