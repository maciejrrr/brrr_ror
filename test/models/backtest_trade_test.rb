require "test_helper"

class BacktestTradeTest < ActiveSupport::TestCase
  test "closed trades require complete exit values" do
    trade = backtest_trades(:completed_trade)
    trade.exit_price = nil

    assert_not trade.valid?
    assert_includes trade.errors[:base], "closed trades require exit time, exit price, and return"
  end

  test "an open position may omit exit values" do
    trade = backtest_runs(:queued).backtest_trades.build(
      entry_time: Time.utc(2024, 1, 2),
      entry_price: 45_000,
      holding_bars: 12,
      open_position: true
    )

    assert trade.valid?
  end

  test "destroying a run deletes its trades" do
    run = backtest_runs(:completed)
    trade_id = backtest_trades(:completed_trade).id

    assert_difference("BacktestTrade.count", -1) { run.destroy! }
    assert_not BacktestTrade.exists?(trade_id)
  end
end
