require "test_helper"

class Backtest::StrategiesTest < ActiveSupport::TestCase
  Candle = Struct.new(:open, :high, :low, :close, :volume)

  test "lists the whitelisted strategies and rejects unknown names" do
    assert_equal BacktestRun::STRATEGY_KEYS.sort, Backtest::Strategies.list.map(&:key).sort
    assert_raises(Backtest::UnknownStrategy) { Backtest::Strategies.fetch("constantize_me") }
  end

  test "resolves defaults and rejects unknown or invalid parameters" do
    assert_equal({ "entry_period" => 168, "exit_period" => 84 }, Backtest::Strategies.resolve("donchian"))
    assert_equal 96, Backtest::Strategies.resolve("donchian", entry_period: 96)["entry_period"]
    assert_raises(Backtest::InvalidStrategyParameters) { Backtest::Strategies.resolve("donchian", typo: 10) }
    assert_raises(Backtest::InvalidStrategyParameters) { Backtest::Strategies.resolve("donchian", entry_period: 0) }
  end

  test "returns one bounded weight per candle" do
    candles = Array.new(20) { |index| Candle.new(100 + index, 101 + index, 99 + index, 100 + index, 10) }
    result = Backtest::Strategies.build_weights(key: "buy_hold", candles:, bars_per_year: 365)

    assert_equal candles.length, result[:weights].length
    assert result[:weights].all? { |weight| weight.between?(0, 1) }
  end
end
