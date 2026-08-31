require "test_helper"

class AssetsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated visitors to sign in" do
    get assets_path
    assert_redirected_to new_session_path

    get asset_path("SPY")
    assert_redirected_to new_session_path
  end

  test "index lists assets" do
    sign_in_as(users(:one))

    get assets_path
    assert_response :success
    assert_select "h1", "Market Data Assets"
    assert_select "td", text: "SPY"
    assert_select "td", text: "BTC"
  end

  test "show renders asset details and chart container" do
    sign_in_as(users(:one))

    get asset_path("SPY")
    assert_response :success
    assert_select "h1", "SPY"
    assert_select "[data-controller='candle-chart']"
  end

  test "show supports interval parameter" do
    sign_in_as(users(:one))

    get asset_path("BTC", params: { interval: "one_hour" })
    assert_response :success
    assert_select "h1", "BTC"
  end
end
