require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "reports healthy when the database session uses UTC" do
    get rails_health_check_path

    assert_response :success
  end
end
