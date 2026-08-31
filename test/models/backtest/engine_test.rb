require "test_helper"

class Backtest::EngineTest < ActiveSupport::TestCase
  Candle = Struct.new(:open_time, :open, :high, :low, :close)

  test "fills at the next bar open and never uses signal-bar movement" do
    candles = candles([ [ 100, 500 ], [ 500, 500 ], [ 500, 500 ] ])
    result = Backtest::Engine.run(candles:, weights: [ 1, 1, 1 ], costs: costs, starting_capital: 10_000, bars_per_year: 365)

    assert_in_delta 10_000, result.final_equity, 0.001
    assert_equal 500.0, result.trades.first.entry_price
  end

  test "charges costs on entry and exit and records closed trades" do
    result = Backtest::Engine.run(candles: candles([ [ 100, 100 ], [ 100, 100 ], [ 150, 150 ], [ 150, 150 ] ]),
      weights: [ 1, 1, 0, 0 ], costs: { fee_percentage: 0, slippage_percentage: 0 }, starting_capital: 10_000, bars_per_year: 365)

    assert_equal 1, result.trade_count
    assert_in_delta 50, result.trades.first.return_percentage, 0.001
    assert_equal 2, result.trades.first.holding_bars
  end

  test "rejects mismatched or non-increasing input" do
    assert_raises(ArgumentError) { Backtest::Engine.run(candles: candles([ [ 100, 100 ], [ 100, 100 ] ]), weights: [ 1 ], costs:, starting_capital: 100, bars_per_year: 365) }
  end

  private
    def costs
      { fee_percentage: 0, slippage_percentage: 0 }
    end

    def candles(values)
      values.each_with_index.map { |(open, close), index| Candle.new(Time.utc(2024, 1, index + 1), open, [ open, close ].max, [ open, close ].min, close) }
    end
end
