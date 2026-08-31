require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated visitors to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "renders for an authenticated user" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "h1", "Research Workspace"
    assert_select "div", text: /Configured Assets/
  end
end
