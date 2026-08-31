require "test_helper"

class BacktestRunTest < ActiveSupport::TestCase
  test "runs are owned by exactly one user" do
    assert_equal [ backtest_runs(:completed) ], users(:one).backtest_runs.to_a
    assert_equal [ backtest_runs(:queued) ], users(:two).backtest_runs.to_a
  end

  test "rejects unknown strategies" do
    run = backtest_runs(:queued)
    run.strategy_key = "constantize_me"

    assert_not run.valid?
    assert run.errors.of_kind?(:strategy_key, :inclusion)
  end

  test "rejects invalid ranges and combined costs" do
    run = backtest_runs(:queued)
    run.assign_attributes(
      from_time: Time.utc(2024, 1, 3),
      to_time: Time.utc(2024, 1, 2),
      fee_percentage: 60,
      slippage_percentage: 40
    )

    assert_not run.valid?
    assert_includes run.errors[:to_time], "must be on or after the start time"
    assert_includes run.errors[:base], "combined fee and slippage must be below 100% per fill"
  end

  test "allows queued configuration changes" do
    run = backtest_runs(:queued)
    run.starting_capital = 30_000

    assert run.valid?
  end

  test "protects configuration after execution starts" do
    run = backtest_runs(:completed)
    run.starting_capital = 30_000

    assert_not run.valid?
    assert_match(/configuration cannot change/, run.errors[:base].join)
  end

  test "rejects non-finite result metrics" do
    run = backtest_runs(:completed)
    run.sharpe_ratio = Float::NAN

    assert_not run.valid?
    assert run.errors.of_kind?(:sharpe_ratio, :not_a_number)
  end
end
