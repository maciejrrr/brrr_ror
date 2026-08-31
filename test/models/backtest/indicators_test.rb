require "test_helper"

class Backtest::IndicatorsTest < ActiveSupport::TestCase
  include Backtest::Indicators

  test "calculates moving averages with aligned warmup" do
    assert_equal [ nil, nil, 2.0, 3.0, 4.0 ], sma([ 1, 2, 3, 4, 5 ], 3)
    assert_equal [ nil, nil, 2.0, 3.0, 4.0 ], ema([ 1, 2, 3, 4, 5 ], 3)
  end

  test "calculates RSI with Wilder smoothing" do
    values = rsi([ 1, 2, 3, 2, 2, 4 ], 3)

    assert_nil values[2]
    assert_in_delta 66.6667, values[3], 0.001
  end

  test "calculates ATR from true ranges including gaps" do
    candles = [
      Struct.new(:high, :low, :close).new(10, 10, 10),
      Struct.new(:high, :low, :close).new(20, 19, 20)
    ]

    assert_in_delta 5.0, atr(candles, 2)[1], 0.0001
  end

  test "calculates rolling extremes and down streaks" do
    assert_equal [ nil, nil, 3, 5, 5 ], rolling_max([ 1, 3, 2, 5, 4 ], 3)
    assert_equal [ nil, nil, 1, 2, 2 ], rolling_min([ 1, 3, 2, 5, 4 ], 3)
    assert_equal [ 0, 1, 2, 0, 1, 2 ], down_streak([ 5, 4, 3, 4, 3, 2 ])
  end

  test "rejects a one-bar volatility window" do
    assert_raises(ArgumentError) { realized_volatility(values: [ 1, 2 ], period: 1, bars_per_year: 365) }
  end
end
