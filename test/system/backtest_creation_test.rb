require "application_system_test_case"

class BacktestCreationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    login_as(@user)
  end

  test "dynamic strategy parameters toggle and asset date bounds update" do
    visit new_backtest_run_path

    # Select SMA Trend -> parameters become visible and enabled
    select "Sma trend — Long above a moving average with hysteresis", from: "Trading Strategy"
    assert_selector "[data-strategy-key='sma_trend']:not(.hidden)"
    assert_selector "input[name='backtest_run[parameters][period]']:not([disabled])"

    # Select Donchian -> donchian fields are shown
    select "Donchian — Long on an N-bar high, flat on an M-bar low", from: "Trading Strategy"
    assert_selector "[data-strategy-key='donchian']:not(.hidden)"
    assert_selector "input[name='backtest_run[parameters][entry_period]']:not([disabled])"

    # Select Buy & Hold -> parameters are hidden and disabled
    select "Buy hold — Always fully invested", from: "Trading Strategy"
    assert_selector "[data-strategy-key='buy_hold']:not(.hidden)"
    assert_selector "[data-strategy-key='sma_trend'].hidden", visible: false
    assert_selector "input[name='backtest_run[parameters][period]'][disabled]", visible: false

    # Select Asset and set dates
    select "SPY · SPDR S&P 500 ETF Trust", from: "Market Asset"
    fill_in "Start Date (UTC)", with: "2024-01-02"
    fill_in "End Date (UTC)", with: "2024-01-03"
    fill_in "Starting Capital ($)", with: "25000"
    fill_in "Fee per fill (%)", with: "0.05"
    fill_in "Optional Label / Note", with: "System Test Run"

    click_on "Launch Backtest"

    assert_current_path %r{/backtest_runs/\d+}
    assert_text "SPY"
    assert_text "System Test Run"
  end
end
