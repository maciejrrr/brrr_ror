require "test_helper"

class BacktestExecutionJobTest < ActiveJob::TestCase
  test "executes queued run, computes strategy and benchmark, and persists trades" do
    asset = assets(:spy)
    user = users(:one)
    run = BacktestRun.create!(
      user: user,
      asset: asset,
      interval: :one_day,
      strategy_key: "buy_hold",
      from_time: Time.utc(2024, 1, 2),
      to_time: Time.utc(2024, 1, 3),
      starting_capital: 10_000,
      fee_percentage: 0.1,
      slippage_percentage: 0.05
    )

    assert run.queued?
    assert_equal({}, run.resolved_parameters)

    BacktestExecutionJob.perform_now(run.id)
    run.reload

    assert run.completed?
    assert_equal 2, run.bar_count
    assert_equal 1, run.trade_count
    assert run.final_equity > 0
    assert_not_nil run.cagr_percentage
    assert_not_nil run.benchmark_cagr_percentage
    assert_equal run.cagr_percentage, run.benchmark_cagr_percentage
    assert_equal run.maximum_drawdown_percentage, run.benchmark_maximum_drawdown_percentage
    assert_equal 2, run.equity_curve.length
    assert run.demo_data?

    trade = run.backtest_trades.first
    assert_not_nil trade
    assert_equal Time.utc(2024, 1, 3), trade.entry_time
    assert_equal 473.0, trade.entry_price.to_f
    assert trade.open_position?
    assert_equal 477.0, trade.exit_price.to_f
  end

  test "records open positions marked to market at end of backtest" do
    asset = assets(:spy)
    user = users(:one)
    run = BacktestRun.create!(
      user: user,
      asset: asset,
      interval: :one_day,
      strategy_key: "buy_hold",
      from_time: Time.utc(2024, 1, 2),
      to_time: Time.utc(2024, 1, 3),
      starting_capital: 10_000,
      fee_percentage: 0.1,
      slippage_percentage: 0.05
    )

    BacktestExecutionJob.perform_now(run.id)
    run.reload

    trade = run.backtest_trades.first
    assert trade.open_position?
    assert_equal 0, trade.holding_bars
    assert trade.return_percentage.present?
  end

  test "transitions to failed when not enough price bars are available" do
    asset = assets(:btc)
    user = users(:two)
    run = BacktestRun.create!(
      user: user,
      asset: asset,
      interval: :one_hour,
      strategy_key: "donchian",
      resolved_parameters: { entry_period: 10, exit_period: 5 },
      from_time: Time.utc(2024, 1, 2, 1, 0, 0),
      to_time: Time.utc(2024, 1, 2, 1, 0, 0),
      starting_capital: 10_000,
      fee_percentage: 0.1,
      slippage_percentage: 0.05
    )

    BacktestExecutionJob.perform_now(run.id)
    run.reload

    assert run.failed?
    assert_match(/At least 2 price bars are required/, run.error_message)
    assert_equal 0, run.backtest_trades.count
  end

  test "ignores runs that are not queued" do
    run = backtest_runs(:completed)
    original_final_equity = run.final_equity

    BacktestExecutionJob.perform_now(run.id)
    run.reload

    assert run.completed?
    assert_equal original_final_equity, run.final_equity
  end

  test "downsamples long equity curves to max display points" do
    asset = assets(:spy)
    user = users(:one)

    base_time = Time.utc(2020, 1, 1)
    bars = 600.times.map do |i|
      {
        asset_id: asset.id,
        interval: PriceBar.intervals[:one_day],
        data_source: PriceBar.data_sources[:demo],
        open_time: base_time + i.days,
        open: 100 + (i % 10),
        high: 105 + (i % 10),
        low: 95 + (i % 10),
        close: 102 + (i % 10),
        volume: 1000,
        created_at: Time.current.utc,
        updated_at: Time.current.utc
      }
    end
    PriceBar.insert_all!(bars)

    run = BacktestRun.create!(
      user: user,
      asset: asset,
      interval: :one_day,
      strategy_key: "buy_hold",
      from_time: base_time,
      to_time: base_time + 599.days,
      starting_capital: 10_000,
      fee_percentage: 0.1,
      slippage_percentage: 0.05
    )

    BacktestExecutionJob.perform_now(run.id)
    run.reload

    assert run.completed?
    assert_equal 600, run.bar_count
    assert_operator run.equity_curve.length, :<=, 500
    assert_equal base_time.iso8601, run.equity_curve.first["time"]
    assert_equal (base_time + 599.days).iso8601, run.equity_curve.last["time"]
  end

  test "atomic rollback on database error during persistence" do
    run = backtest_runs(:queued)
    run.update_columns(strategy_key: "buy_hold", resolved_parameters: {})
    PriceBar.create!(
      asset: run.asset,
      interval: run.interval,
      data_source: :demo,
      open_time: Time.utc(2024, 1, 2, 2, 0, 0),
      open: 45000, high: 45500, low: 44800, close: 45200, volume: 100
    )

    BacktestTrade.singleton_class.define_method(:insert_all!) do |*|
      raise ActiveRecord::StatementInvalid, "Simulated DB failure"
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      BacktestExecutionJob.perform_now(run.id)
    end
  ensure
    BacktestTrade.singleton_class.remove_method(:insert_all!) rescue nil
  end
end
