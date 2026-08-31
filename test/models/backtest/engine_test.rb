require "test_helper"

class Backtest::EngineTest < ActiveSupport::TestCase
  Candle = Struct.new(:open_time, :open, :high, :low, :close)

  test "fills at the next bar open and never uses signal-bar movement" do
    c = candles([ [ 100, 500 ], [ 500, 500 ], [ 500, 500 ] ])
    result = Backtest::Engine.run(candles: c, weights: [ 1, 1, 1 ], costs: costs, starting_capital: 10_000, bars_per_year: 365)

    assert_in_delta 10_000, result.final_equity, 0.001
    assert_equal 500.0, result.trades.first.entry_price
  end

  test "charges costs on entry and exit and records closed trades" do
    result = Backtest::Engine.run(
      candles: candles([ [ 100, 100 ], [ 100, 100 ], [ 150, 150 ], [ 150, 150 ] ]),
      weights: [ 1, 1, 0, 0 ],
      costs: { fee_percentage: 0.1, slippage_percentage: 0.05 },
      starting_capital: 10_000,
      bars_per_year: 365
    )

    assert_equal 1, result.trade_count
    assert result.trades.first.return_percentage.present?
    assert_equal 2, result.trades.first.holding_bars
    assert_equal 100.0, result.win_rate_percentage
  end

  test "handles open position at the end of backtest window" do
    result = Backtest::Engine.run(
      candles: candles([ [ 100, 100 ], [ 100, 110 ], [ 110, 120 ] ]),
      weights: [ 1, 1, 1 ],
      costs:,
      starting_capital: 10_000,
      bars_per_year: 365
    )

    assert_equal 1, result.trades.length
    assert result.trades.first.open_position
    assert_equal 0.0, result.win_rate_percentage # Open positions excluded from win rate
  end

  test "handles string cost keys and alternative fee pct names" do
    result = Backtest::Engine.run(
      candles: candles([ [ 100, 100 ], [ 100, 100 ] ]),
      weights: [ 0, 0 ],
      costs: { "fee_pct" => 0.05, "slippage_pct" => 0.02 },
      starting_capital: 10_000,
      bars_per_year: 365
    )
    assert_in_delta 10_000, result.final_equity, 0.001
  end

  test "skips tiny rebalances under 0.5 percent threshold" do
    result = Backtest::Engine.run(
      candles: candles([ [ 100, 100 ], [ 100, 100 ], [ 100, 100 ] ]),
      weights: [ 0.5, 0.501, 0.501 ],
      costs:,
      starting_capital: 10_000,
      bars_per_year: 365
    )
    assert_equal 1, result.trades.length
  end

  test "clamps non-finite or out-of-bounds weights" do
    result = Backtest::Engine.run(
      candles: candles([ [ 100, 100 ], [ 100, 100 ] ]),
      weights: [ Float::NAN, 2.5 ],
      costs:,
      starting_capital: 10_000,
      bars_per_year: 365
    )
    assert result.final_equity.positive?
  end

  test "rejects mismatched or non-increasing input" do
    assert_raises(ArgumentError) do
      Backtest::Engine.run(candles: candles([ [ 100, 100 ], [ 100, 100 ] ]), weights: [ 1 ], costs:, starting_capital: 100, bars_per_year: 365)
    end

    assert_raises(ArgumentError) do
      Backtest::Engine.run(candles: [ Candle.new(Time.utc(2024, 1, 1), 100, 100, 100, 100) ], weights: [ 1 ], costs:, starting_capital: 100, bars_per_year: 365)
    end

    assert_raises(ArgumentError) do
      Backtest::Engine.run(candles: candles([ [ 100, 100 ], [ 100, 100 ] ]), weights: [ 1, 1 ], costs:, starting_capital: -5, bars_per_year: 365)
    end

    assert_raises(ArgumentError) do
      Backtest::Engine.run(candles: candles([ [ 100, 100 ], [ 100, 100 ] ]), weights: [ 1, 1 ], costs:, starting_capital: 100, bars_per_year: 0)
    end

    assert_raises(ArgumentError) do
      Backtest::Engine.run(candles: candles([ [ 100, 100 ], [ 100, 100 ] ]), weights: [ 1, 1 ], costs: { fee_percentage: 60, slippage_percentage: 50 }, starting_capital: 100, bars_per_year: 365)
    end

    assert_raises(ArgumentError) do
      c = [
        Candle.new(Time.utc(2024, 1, 2), 100, 100, 100, 100),
        Candle.new(Time.utc(2024, 1, 1), 100, 100, 100, 100)
      ]
      Backtest::Engine.run(candles: c, weights: [ 1, 1 ], costs:, starting_capital: 100, bars_per_year: 365)
    end

    assert_raises(ArgumentError) do
      c = [
        Candle.new(Time.utc(2024, 1, 1), -10, 100, 100, 100),
        Candle.new(Time.utc(2024, 1, 2), 100, 100, 100, 100)
      ]
      Backtest::Engine.run(candles: c, weights: [ 1, 1 ], costs:, starting_capital: 100, bars_per_year: 365)
    end
  end

  private
    def costs
      { fee_percentage: 0, slippage_percentage: 0 }
    end

    def candles(values)
      values.each_with_index.map do |(open, close), index|
        Candle.new(Time.utc(2024, 1, index + 1), open, [ open, close ].max, [ open, close ].min, close)
      end
    end
end
