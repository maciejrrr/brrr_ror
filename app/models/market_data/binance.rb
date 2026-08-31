module MarketData
  class Binance
    PATH = "/api/v3/klines"
    LIMIT = 1_000
    MAX_PAGES = 500
    PAGE_DELAY = 0.12
    INTERVALS = { "one_hour" => [ "1h", 3_600_000 ], "one_day" => [ "1d", 86_400_000 ] }.freeze

    def initialize(http_client: nil, sleeper: ->(seconds) { sleep(seconds) })
      @http_client = http_client || HttpClient.new(base_url: ENV.fetch("BINANCE_BASE_URL"))
      @sleeper = sleeper
    end

    def supported_intervals
      INTERVALS.keys
    end

    def fetch(symbol:, interval:, from:, to:, as_of:)
      interval_code, duration = INTERVALS.fetch(interval) { raise UnsupportedInterval, "Binance does not support #{interval}" }
      bars = []
      seen = {}
      cursor = from.to_time.to_i * 1_000
      ending = to.to_time.to_i * 1_000

      completed = paginate(symbol:, interval_code:, duration:, ending:, seen:, bars:, as_of:, cursor:)
      raise Error, "Binance pagination exceeded #{MAX_PAGES} pages" unless completed || cursor > ending

      bars.sort_by(&:open_time)
    end

    private
      def paginate(symbol:, interval_code:, duration:, ending:, seen:, bars:, as_of:, cursor:)
        MAX_PAGES.times do
          return true if cursor > ending

          rows = fetch_page(symbol, interval_code, cursor, ending)
          return true if rows.empty?

          process_rows(rows, duration:, ending:, seen:, bars:, as_of:)
          return true if rows.length < LIMIT

          next_cursor = Integer(rows.last.fetch(0)) + duration
          raise Error, "Binance pagination cursor did not advance" if next_cursor <= cursor

          cursor = next_cursor
          @sleeper.call(PAGE_DELAY)
        end
        false
      end

      def fetch_page(symbol, interval_code, cursor, ending)
        @http_client.get_json(PATH, params: {
          symbol:, interval: interval_code, startTime: cursor, endTime: ending, limit: LIMIT
        })
      end

      def process_rows(rows, duration:, ending:, seen:, bars:, as_of:)
        rows.each do |row|
          open_ms = Integer(row.fetch(0))
          next if open_ms > ending || seen[open_ms]

          candle = build_candle(row, duration)
          next unless candle.closed_as_of?(as_of)

          seen[open_ms] = true
          bars << candle
        end
      end

      def build_candle(row, duration)
        open_ms = Integer(row.fetch(0))
        Candle.new(
          open_time: Time.at(open_ms / 1_000, (open_ms % 1_000) * 1_000).utc,
          close_time: Time.at((open_ms + duration) / 1_000, ((open_ms + duration) % 1_000) * 1_000).utc,
          open: row.fetch(1), high: row.fetch(2), low: row.fetch(3),
          close: row.fetch(4), volume: row.fetch(5)
        )
      end
  end
end
