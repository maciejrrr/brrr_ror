require "test_helper"

class MarketData::DateRangeTest < ActiveSupport::TestCase
  test "parses string dates and normalizes to UTC boundaries" do
    range = MarketData::DateRange.parse(from: "2024-01-01", to: "2024-01-05")

    assert_equal Time.utc(2024, 1, 1).beginning_of_day, range.from
    assert_equal Time.utc(2024, 1, 5).end_of_day, range.to
    assert_equal "2024-01-01T00:00:00Z", range.from_iso8601
  end

  test "uses defaults when dates are omitted" do
    range = MarketData::DateRange.parse(default_days: 10)

    assert_equal 10.days.ago.beginning_of_day.utc.to_i, range.from.to_i
    assert_in_delta Time.current.utc.to_i, range.to.to_i, 5
  end
end
