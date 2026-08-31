require "test_helper"

class MarketData::ImporterTest < ActiveSupport::TestCase
  test "upserts provider candles without converting decimals to floats" do
    candle = MarketData::Candle.new(
      open_time: Time.utc(2024, 1, 1), close_time: Time.utc(2024, 1, 2),
      open: "0.000000000000000001", high: "2", low: "0.000000000000000001", close: "1.5", volume: "10"
    )
    provider = StubProvider.new(candle)

    result = MarketData::Importer.new(provider_registry: { "yahoo_finance" => provider, "binance" => provider }).call(
      from: Time.utc(2024, 1, 1), to: Time.utc(2024, 1, 2), as_of: Time.utc(2024, 1, 3)
    )

    assert_equal({ assets_imported: 2, assets_failed: 0, bars_upserted: 3 }, result)
    assert_equal BigDecimal("0.000000000000000001"), assets(:spy).price_bars.provider.first.open
  end

  test "isolates provider failures per asset" do
    result = MarketData::Importer.new(provider_registry: {
      "yahoo_finance" => StubProvider.new(nil, error: "provider unavailable"),
      "binance" => StubProvider.new(nil, error: "provider unavailable")
    }).call(from: Time.utc(2024, 1, 1), to: Time.utc(2024, 1, 2), as_of: Time.utc(2024, 1, 3))

    assert_equal 0, result[:assets_imported]
    assert_equal 2, result[:assets_failed]
  end

  test "overlaps the latest five candles on repeat imports" do
    provider = StubProvider.new(nil, error: "provider unavailable")
    latest = assets(:spy).price_bars.one_day.maximum(:open_time)
    calls = []
    provider.define_singleton_method(:fetch) do |**arguments|
      calls << arguments
      raise "stop after checking the cursor"
    end

    MarketData::Importer.new(provider_registry: { "yahoo_finance" => provider, "binance" => provider }).call(
      from: Time.utc(2024, 1, 10), to: Time.utc(2024, 1, 11), as_of: Time.utc(2024, 1, 12)
    )

    assert_equal latest - 5.days, calls.find { |call| call[:symbol] == "SPY" }[:from]
  end

  class StubProvider
    def initialize(candle, error: nil)
      @candle = candle
      @error = error
    end

    def fetch(**)
      raise @error if @error

      [ @candle ]
    end
  end
end
