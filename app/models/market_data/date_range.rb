module MarketData
  class DateRange
    attr_reader :from, :to

    def self.parse(from: nil, to: nil, default_days: 30)
      from_time = parse_from(from, default_days)
      to_time = parse_to(to)

      new(from: from_time, to: to_time)
    end

    def self.parse_from(from, default_days)
      if from.present?
        Time.zone.parse(from.to_s)&.beginning_of_day&.utc || default_days.days.ago.beginning_of_day.utc
      else
        default_days.days.ago.beginning_of_day.utc
      end
    end
    private_class_method :parse_from

    def self.parse_to(to)
      if to.present?
        Time.zone.parse(to.to_s)&.end_of_day&.utc || Time.current.utc
      else
        Time.current.utc
      end
    end
    private_class_method :parse_to

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
