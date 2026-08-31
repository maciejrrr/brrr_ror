require "test_helper"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1400, 1400 ],
    browser_options: {
      "no-sandbox" => nil,
      "disable-gpu" => nil,
      "disable-dev-shm-usage" => nil
    },
    process_timeout: 15,
    timeout: 10,
    headless: !ENV["HEADLESS"].in?(%w[0 false no])
  )
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite

  def login_as(user, password = "password")
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: password
    click_button "Sign in"
    assert_current_path root_path
  end
end
