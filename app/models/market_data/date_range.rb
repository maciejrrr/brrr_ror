module MarketData
  class DateRange
    attr_reader :from, :to

    def self.parse(from: nil, to: nil, default_days: 30)
      from_time = if from.present?
        Time.zone.parse(from.to_s)&.beginning_of_day&.utc
      else
        default_days.days.ago.beginning_of_day.utc
      end

      to_time = if to.present?
        Time.zone.parse(to.to_s)&.end_of_day&.utc
      else
        Time.current.utc
      end

      new(from: from_time || default_days.days.ago.beginning_of_day.utc, to: to_time || Time.current.utc)
    end

    def initialize(from:, to:)
      @from = from
      @to = to
    end

    def from_iso8601
      @from.iso8601
    end

    def to_iso8601
      @to.iso8601
    end

    def range
      @from..@to
    end
  end
end
