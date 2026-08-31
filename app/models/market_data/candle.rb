require "bigdecimal"

module MarketData
  class Candle
    ATTRIBUTES = %i[ open_time close_time open high low close volume ].freeze
    attr_reader(*ATTRIBUTES)

    def initialize(open_time:, close_time:, open:, high:, low:, close:, volume:)
      @open_time = open_time.utc
      @close_time = close_time.utc
      @open = decimal(open)
      @high = decimal(high)
      @low = decimal(low)
      @close = decimal(close)
      @volume = decimal(volume)
    end

    def closed_as_of?(as_of)
      close_time <= as_of.utc
    end

    private
      def decimal(value)
        BigDecimal(value.to_s)
      end
  end
end
