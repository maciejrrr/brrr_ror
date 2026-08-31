require "uri"

module MarketData
  class YahooFinance
    PATH = "/v8/finance/chart"
    DAY = 86_400

    def initialize(http_client: nil)
      @http_client = http_client || HttpClient.new(base_url: ENV.fetch("YAHOO_FINANCE_BASE_URL"))
    end

    def supported_intervals
      [ "one_day" ]
    end

    def fetch(symbol:, interval:, from:, to:, as_of:)
      raise UnsupportedInterval, "Yahoo Finance only supports one_day" unless interval == "one_day"

      payload = @http_client.get_json("#{PATH}/#{URI.encode_www_form_component(symbol)}", params: {
        period1: from.to_time.to_i, period2: to.to_time.to_i, interval: "1d"
      })
      result = payload.dig("chart", "result", 0)
      raise InvalidResponse, "Yahoo Finance response had no result" unless result

      timestamps = result.fetch("timestamp", [])
      quote = result.dig("indicators", "quote", 0) || {}
      timestamps.each_with_index.filter_map do |timestamp, index|
        values = %w[open high low close volume].to_h { |field| [ field, quote.fetch(field, [])[index] ] }
        next if values.values.any?(&:nil?)

        open_time = Time.at(timestamp).utc.change(hour: 0, min: 0, sec: 0)
        candle = Candle.new(open_time:, close_time: open_time + DAY, **values.transform_keys(&:to_sym))
        candle if candle.closed_as_of?(as_of)
      end
    end
  end
end
