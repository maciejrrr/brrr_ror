require "test_helper"

class Backtest::StrategiesTest < ActiveSupport::TestCase
  Candle = Struct.new(:open, :high, :low, :close, :volume)

  test "lists the whitelisted strategies and rejects unknown names" do
    assert_equal BacktestRun::STRATEGY_KEYS.sort, Backtest::Strategies.list.map(&:key).sort
    assert_raises(Backtest::UnknownStrategy) { Backtest::Strategies.fetch("constantize_me") }
  end

  test "parameter_keys returns unique list of all parameters" do
    keys = Backtest::Strategies.parameter_keys
    assert_includes keys, "entry_period"
    assert_includes keys, "period"
    assert_includes keys, "fast_period"
  end

  test "resolves defaults and rejects unknown or invalid parameters" do
    assert_equal({ "entry_period" => 168, "exit_period" => 84 }, Backtest::Strategies.resolve("donchian"))
    assert_equal 96, Backtest::Strategies.resolve("donchian", entry_period: 96)["entry_period"]
    assert_equal 96, Backtest::Strategies.resolve("donchian", "entry_period" => "96")["entry_period"]
    assert_equal 5.5, Backtest::Strategies.resolve("sma_trend", "band_pct" => "5.5")["band_pct"]
    assert_raises(Backtest::InvalidStrategyParameters) { Backtest::Strategies.resolve("donchian", typo: 10) }
    assert_raises(Backtest::InvalidStrategyParameters) { Backtest::Strategies.resolve("donchian", entry_period: 0) }
    assert_raises(Backtest::InvalidStrategyParameters) { Backtest::Strategies.resolve("sma_trend", band_pct: -1) }
  end

  test "buy_hold returns constant 1.0 weights" do
    candles = Array.new(10) { |i| Candle.new(100, 105, 95, 100, 1000) }
    result = Backtest::Strategies.build_weights(key: "buy_hold", candles:, bars_per_year: 365)
    assert_equal [ 1.0 ] * 10, result[:weights]
  end

  test "donchian breakout enters on high and exits on low" do
    candles = [
      Candle.new(10, 10, 10, 10, 100),
      Candle.new(10, 10, 10, 10, 100),
      Candle.new(10, 20, 10, 20, 100),
      Candle.new(20, 20, 20, 20, 100),
      Candle.new(20, 20, 5, 5, 100),
      Candle.new(5, 5, 5, 5, 100)
    ]
    result = Backtest::Strategies.build_weights(
      key: "donchian",
      candles:,
      params: { "entry_period" => 2, "exit_period" => 2 },
      bars_per_year: 365
    )
    assert_equal [ 0.0, 0.0, 1.0, 1.0, 0.0, 0.0 ], result[:weights]
  end

  test "sma_trend toggles position with hysteresis bands" do
    candles = [
      Candle.new(100, 100, 100, 100, 100),
      Candle.new(100, 100, 100, 100, 100),
      Candle.new(100, 120, 100, 120, 100),
      Candle.new(120, 120, 110, 110, 100),
      Candle.new(110, 110, 80, 80, 100),
      Candle.new(80, 80, 80, 80, 100)
    ]
    result = Backtest::Strategies.build_weights(
      key: "sma_trend",
      candles:,
      params: { "period" => 2, "band_pct" => 5 },
      bars_per_year: 365
    )
    assert_equal [ 0.0, 0.0, 1.0, 1.0, 0.0, 0.0 ], result[:weights]
  end

  test "ma_cross goes long when fast exceeds slow" do
    candles = [
      Candle.new(10, 10, 10, 10, 100),
      Candle.new(10, 10, 10, 10, 100),
      Candle.new(10, 10, 10, 10, 100),
      Candle.new(20, 20, 20, 20, 100),
      Candle.new(30, 30, 30, 30, 100),
      Candle.new(5, 5, 5, 5, 100)
    ]
    result = Backtest::Strategies.build_weights(
      key: "ma_cross",
      candles:,
      params: { "fast_period" => 2, "slow_period" => 3 },
      bars_per_year: 365
    )
    assert_equal 6, result[:weights].length
    assert result[:weights].all? { |w| [ 0.0, 1.0 ].include?(w) }
  end

  test "mean_reversion enters on dips below ATR band and exits on mean recovery" do
    candles = [
      Candle.new(100, 102, 98, 100, 100),
      Candle.new(100, 102, 98, 100, 100),
      Candle.new(100, 102, 98, 100, 100),
      Candle.new(100, 100, 70, 75, 100),  # Dip below SMA - 2*ATR
      Candle.new(75, 105, 75, 102, 100),  # Rebound above SMA
      Candle.new(102, 102, 100, 100, 100)
    ]
    result = Backtest::Strategies.build_weights(
      key: "mean_reversion",
      candles:,
      params: { "sma_period" => 3, "atr_period" => 2, "atr_mult" => 1 },
      bars_per_year: 365
    )
    assert_equal 6, result[:weights].length
    assert result[:weights].all? { |w| [ 0.0, 1.0 ].include?(w) }
  end

  test "volatility_target scales exposure based on realized volatility" do
    candles = Array.new(30) { |i| Candle.new(100 + i, 101 + i, 99 + i, 100 + (i % 2 == 0 ? 5 : -5), 100) }
    result = Backtest::Strategies.build_weights(
      key: "volatility_target",
      candles:,
      params: { "period" => 10, "target_vol_pct" => 20 },
      bars_per_year: 365
    )
    assert_equal 30, result[:weights].length
    assert result[:weights].all? { |w| w.between?(0.0, 1.0) }
  end

  test "wyckoff_accumulation detects spring and sign of strength" do
    candles = [
      Candle.new(100, 105, 95, 100, 100),
      Candle.new(100, 105, 95, 100, 100),
      Candle.new(100, 105, 95, 100, 100),
      Candle.new(100, 102, 90, 96, 300),  # Spring: low < range low, close > range low, volume spike
      Candle.new(96, 110, 96, 108, 250),  # SOS: close > range high, strong volume
      Candle.new(108, 112, 106, 110, 100),
      Candle.new(110, 110, 80, 82, 100)    # Exit on breakdown below exit_period low
    ]
    result = Backtest::Strategies.build_weights(
      key: "wyckoff_accumulation",
      candles:,
      params: {
        "range_period" => 3,
        "range_max_width_pct" => 30,
        "vol_avg_period" => 3,
        "spring_vol_mult" => 1.5,
        "sos_vol_mult" => 1.3,
        "sos_window_bars" => 5,
        "exit_period" => 3
      },
      bars_per_year: 365
    )
    assert_equal 7, result[:weights].length
    assert result[:weights].all? { |w| [ 0.0, 1.0 ].include?(w) }
  end
end
