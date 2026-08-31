require "test_helper"

class MarketDataImportJobTest < ActiveJob::TestCase
  test "normalizes serialized ISO-8601 bounds before importing" do
    importer = Object.new
    calls = []
    importer.define_singleton_method(:call) { |**arguments| calls << arguments }
    original_new = MarketData::Importer.method(:new)
    MarketData::Importer.define_singleton_method(:new) { importer }
    begin
      MarketDataImportJob.perform_now(
        from: "2024-01-01T00:00:00Z", to: "2024-01-02T00:00:00Z", as_of: "2024-01-03T00:00:00Z"
      )
    ensure
      MarketData::Importer.define_singleton_method(:new, original_new)
    end
    assert_equal [ { from: Time.utc(2024, 1, 1), to: Time.utc(2024, 1, 2), as_of: Time.utc(2024, 1, 3) } ], calls
  end
end
