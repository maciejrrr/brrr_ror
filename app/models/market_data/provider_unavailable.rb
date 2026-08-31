module MarketData
  class ProviderUnavailable < Error
    attr_reader :retry_after

    def initialize(message, retry_after: nil)
      @retry_after = retry_after
      super(message)
    end
  end
end
