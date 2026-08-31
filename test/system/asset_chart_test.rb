require "application_system_test_case"

class AssetChartTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    login_as(@user)
  end

  test "renders asset candlestick chart canvas and switches interval" do
    visit asset_path("SPY")

    assert_selector "h1", text: "SPY"
    assert_selector "[data-controller='candle-chart']"

    # Verify TradingView Lightweight Charts canvas is mounted
    assert_selector "[data-controller='candle-chart'] canvas"

    # Click interval link
    click_link "One day"
    assert_current_path %r{/assets/SPY.*}
    assert_selector "h1", text: "SPY"
    assert_selector "[data-controller='candle-chart'] canvas"
  end
end
