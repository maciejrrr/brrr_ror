require "test_helper"

class MarketData::HttpClientTest < ActiveSupport::TestCase
  test "parses successful JSON responses" do
    stub_request(:get, "https://example.test/candles?symbol=BTCUSDT").to_return(body: '{"ok":true}')

    response = client.get_json("/candles", params: { symbol: "BTCUSDT" })

    assert_equal({ "ok" => true }, response)
  end

  test "retries transient server errors with bounded backoff" do
    delays = []
    stub_request(:get, "https://example.test/candles").to_return(status: 500).then.to_return(body: '{"ok":true}')
    c = MarketData::HttpClient.new(base_url: "https://example.test", sleeper: ->(seconds) { delays << seconds })

    assert_equal({ "ok" => true }, c.get_json("/candles"))
    assert_equal [ 1 ], delays
  end

  test "honors a short retry-after on rate limits" do
    delays = []
    stub_request(:get, "https://example.test/candles").to_return(status: 429, headers: { "Retry-After" => "2" }).then.to_return(body: '{"ok":true}')
    c = MarketData::HttpClient.new(base_url: "https://example.test", sleeper: ->(seconds) { delays << seconds })

    assert_equal({ "ok" => true }, c.get_json("/candles"))
    assert_equal [ 2 ], delays
  end

  test "honors HTTP-date format in Retry-After header" do
    delays = []
    future_date = (Time.now.utc + 3).httpdate
    stub_request(:get, "https://example.test/candles").to_return(status: 429, headers: { "Retry-After" => future_date }).then.to_return(body: '{"ok":true}')
    c = MarketData::HttpClient.new(base_url: "https://example.test", sleeper: ->(seconds) { delays << seconds })

    assert_equal({ "ok" => true }, c.get_json("/candles"))
    assert delays.first >= 1
  end

  test "raises MarketData::Error on excessive retry-after" do
    stub_request(:get, "https://example.test/candles").to_return(status: 429, headers: { "Retry-After" => "3600" })

    assert_raises(MarketData::Error) { client.get_json("/candles") }
  end

  test "does not retry a provider ban (418)" do
    stub_request(:get, "https://example.test/candles").to_return(status: 418)

    assert_raises(MarketData::ProviderUnavailable) { client.get_json("/candles") }
  end

  test "retries on network timeout before raising" do
    delays = []
    stub_request(:get, "https://example.test/candles").to_timeout.then.to_return(body: '{"ok":true}')
    c = MarketData::HttpClient.new(base_url: "https://example.test", sleeper: ->(seconds) { delays << seconds })

    assert_equal({ "ok" => true }, c.get_json("/candles"))
    assert_equal [ 1 ], delays
  end

  test "raises MarketData::Error on invalid JSON response" do
    stub_request(:get, "https://example.test/candles").to_return(body: "not json <html/>")

    assert_raises(MarketData::Error) { client.get_json("/candles") }
  end

  private
    def client
      MarketData::HttpClient.new(base_url: "https://example.test", sleeper: ->(_seconds) { })
    end
end
