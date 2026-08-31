require "test_helper"

class MarketData::YahooFinanceTest < ActiveSupport::TestCase
  test "maps daily quote data and omits a forming day" do
    timestamp = Time.utc(2024, 1, 1).to_i
    body = {
      chart: { result: [ { timestamp: [ timestamp ], indicators: { quote: [ { open: [ "1.1" ], high: [ 2.0 ], low: [ 1.0 ], close: [ 1.5 ], volume: [ 10 ] } ] } } ] }
    }
    stub_request(:get, %r{https://query1\.finance\.yahoo\.com/v8/finance/chart/SPY.*}).to_return(body: JSON.generate(body))

    bars = provider.fetch(symbol: "SPY", interval: "one_day", from: Time.utc(2024, 1, 1), to: Time.utc(2024, 1, 3), as_of: Time.utc(2024, 1, 3))

    assert_equal 1, bars.length
    assert_equal BigDecimal("1.1"), bars.first.open
    assert_equal Time.utc(2024, 1, 1), bars.first.open_time
  end

  test "skips candles with missing / nil fields" do
    timestamp1 = Time.utc(2024, 1, 1).to_i
    timestamp2 = Time.utc(2024, 1, 2).to_i
    body = {
      chart: { result: [ { timestamp: [ timestamp1, timestamp2 ], indicators: { quote: [ { open: [ "1.1", nil ], high: [ 2.0, 2.0 ], low: [ 1.0, 1.0 ], close: [ 1.5, 1.5 ], volume: [ 10, 10 ] } ] } } ] }
    }
    stub_request(:get, %r{https://query1\.finance\.yahoo\.com/v8/finance/chart/SPY.*}).to_return(body: JSON.generate(body))

    bars = provider.fetch(symbol: "SPY", interval: "one_day", from: Time.utc(2024, 1, 1), to: Time.utc(2024, 1, 3), as_of: Time.utc(2024, 1, 4))
    assert_equal 1, bars.length
  end

  test "raises InvalidResponse on empty result chart" do
    body = { chart: { result: nil, error: { code: "Not Found" } } }
    stub_request(:get, %r{https://query1\.finance\.yahoo\.com/v8/finance/chart/SPY.*}).to_return(body: JSON.generate(body))

    assert_raises(MarketData::InvalidResponse) do
      provider.fetch(symbol: "SPY", interval: "one_day", from: Time.utc(2024, 1, 1), to: Time.utc(2024, 1, 2), as_of: Time.utc(2024, 1, 3))
    end
  end

  test "only supports daily candles" do
    assert_equal [ "one_day" ], provider.supported_intervals
    assert_raises(MarketData::UnsupportedInterval) do
      provider.fetch(symbol: "SPY", interval: "one_hour", from: Time.current, to: Time.current, as_of: Time.current)
    end
  end

  private
    def provider
      MarketData::YahooFinance.new(
        http_client: MarketData::HttpClient.new(base_url: "https://query1.finance.yahoo.com")
      )
    end
end
