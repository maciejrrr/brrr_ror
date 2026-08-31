require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "successful login and logout in real browser" do
    visit new_session_path

    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path root_path
    assert_text "Market Data Assets"

    click_button "Sign out"
    assert_current_path new_session_path
  end

  test "failed login with invalid credentials" do
    visit new_session_path

    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "wrong_password"
    click_button "Sign in"

    assert_text "Try another email address or password"
    assert_current_path new_session_path
  end
end
