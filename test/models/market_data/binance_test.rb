require "test_helper"

class MarketData::BinanceTest < ActiveSupport::TestCase
  test "maps exact decimal strings and filters forming candles" do
    url = "https://api.binance.com/api/v3/klines"
    open_ms = Time.utc(2024, 1, 1).to_i * 1_000
    rows = [ [ open_ms, "1.123456789012345678", "2", "1", "1.5", "4.000000000000000001", open_ms + 3_599_999 ] ]
    stub_request(:get, %r{#{Regexp.escape(url)}}).to_return(body: JSON.generate(rows))

    bars = provider.fetch(symbol: "BTCUSDT", interval: "one_hour", from: Time.at(open_ms / 1_000), to: Time.at(open_ms / 1_000), as_of: Time.utc(2024, 1, 2))

    assert_equal 1, bars.length
    assert_equal BigDecimal("1.123456789012345678"), bars.first.open
    assert_equal Time.utc(2024, 1, 1), bars.first.open_time
  end

  test "advertises hourly and daily intervals" do
    assert_equal %w[ one_hour one_day ], provider.supported_intervals
  end

  private
    def provider
      MarketData::Binance.new(
        http_client: MarketData::HttpClient.new(base_url: "https://api.binance.com"),
        sleeper: ->(_seconds) { }
      )
    end
end
