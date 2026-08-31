require "test_helper"

class BacktestFlowTest < ActionDispatch::IntegrationTest
  test "complete user flow: sign in, inspect asset, launch and view backtest, sync data" do
    user = users(:one)

    # 1. Sign in
    get new_session_path
    assert_response :success

    post session_path, params: { email_address: user.email_address, password: "password" }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "h1", "Research Workspace"

    # 2. View assets
    get assets_path
    assert_response :success
    assert_select "h1", "Market Data Assets"

    get asset_path("SPY")
    assert_response :success
    assert_select "h1", "SPY"
    assert_select "[data-controller='candle-chart']"

    # 3. Open new backtest form
    get new_backtest_run_path
    assert_response :success
    assert_select "h1", "Configure New Backtest"

    # 4. Submit backtest
    perform_enqueued_jobs do
      post backtest_runs_path, params: {
        backtest_run: {
          asset_id: assets(:spy).id,
          interval: "one_day",
          strategy_key: "buy_hold",
          from_time: "2024-01-01",
          to_time: "2024-01-03",
          starting_capital: 10_000,
          fee_percentage: 0.05,
          slippage_percentage: 0.02,
          label: "E2E Test Run"
        }
      }
    end

    run = BacktestRun.last
    assert_equal "completed", run.status
    assert_equal 2, run.bar_count
    assert_redirected_to backtest_run_path(run)

    # 5. Inspect backtest results page
    follow_redirect!
    assert_response :success
    assert_select "h1", text: /E2E Test Run/
    assert_select "div", text: /Final Equity/
    assert_select "div", text: /CAGR vs Buy & Hold/
    assert_select "[data-controller='equity-chart']"
    assert_select "table" # trades log table

    # 6. Trigger data sync
    assert_enqueued_with(job: MarketDataImportJob) do
      post market_data_imports_path
    end
    assert_redirected_to root_path
  end
end
