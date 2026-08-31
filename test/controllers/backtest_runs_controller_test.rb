require "test_helper"

class BacktestRunsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated visitors to sign in" do
    get backtest_runs_path
    assert_redirected_to new_session_path

    get new_backtest_run_path
    assert_redirected_to new_session_path

    post backtest_runs_path
    assert_redirected_to new_session_path
  end

  test "index displays current user runs" do
    sign_in_as(users(:one))

    get backtest_runs_path
    assert_response :success
    assert_select "h1", "Backtest Runs"
    assert_select "td", text: "SPY"
  end

  test "new renders backtest creation form" do
    sign_in_as(users(:one))

    get new_backtest_run_path
    assert_response :success
    assert_select "h1", "Configure New Backtest"
    assert_select "form"
  end

  test "create enqueues backtest execution job and redirects" do
    sign_in_as(users(:one))

    assert_enqueued_with(job: BacktestExecutionJob) do
      post backtest_runs_path, params: {
        backtest_run: {
          asset_id: assets(:spy).id,
          interval: "one_day",
          strategy_key: "donchian",
          starting_capital: 10_000,
          fee_percentage: 0.05,
          slippage_percentage: 0.02,
          from_time: "2024-01-01",
          to_time: "2024-12-31",
          label: "Test Run",
          parameters: {
            entry_period: 20,
            exit_period: 10
          }
        }
      }
    end

    run = BacktestRun.last
    assert_equal users(:one), run.user
    assert_equal "donchian", run.strategy_key
    assert_equal({ "entry_period" => 20, "exit_period" => 10 }, run.resolved_parameters)
    assert_redirected_to backtest_run_path(run)
  end

  test "create with invalid params renders new with 422" do
    sign_in_as(users(:one))

    post backtest_runs_path, params: {
      backtest_run: {
        asset_id: assets(:spy).id,
        interval: "one_day",
        strategy_key: "donchian",
        starting_capital: -100,
        from_time: "2024-01-01",
        to_time: "2024-12-31"
      }
    }

    assert_response :unprocessable_entity
    assert_select "div", text: /Unable to start backtest/
  end

  test "show displays completed backtest run" do
    sign_in_as(users(:one))
    run = backtest_runs(:completed)

    get backtest_run_path(run)
    assert_response :success
    assert_select "h1", text: /#{run.display_name}/
    assert_select "[data-controller='equity-chart']"
  end

  test "show displays failed run error message" do
    user = users(:one)
    run = BacktestRun.create!(
      user: user,
      asset: assets(:spy),
      interval: :one_day,
      strategy_key: "buy_hold",
      from_time: Time.utc(2024, 1, 1),
      to_time: Time.utc(2024, 1, 2),
      starting_capital: 10_000,
      fee_percentage: 0.05,
      slippage_percentage: 0.02,
      status: :failed,
      error_message: "Simulated domain execution failure"
    )

    sign_in_as(user)
    get backtest_run_path(run)
    assert_response :success
    assert_select "div", text: /Simulated domain execution failure/
  end

  test "strict scoping: user cannot view another user's backtest run" do
    sign_in_as(users(:one))
    other_user_run = backtest_runs(:queued) # owned by user :two

    get backtest_run_path(other_user_run)
    assert_response :not_found
  end

  test "destroy deletes user run" do
    sign_in_as(users(:one))
    run = backtest_runs(:completed)

    assert_difference("BacktestRun.count", -1) do
      delete backtest_run_path(run)
    end

    assert_redirected_to backtest_runs_path
  end
end
