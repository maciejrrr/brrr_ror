class MarketDataImportJob < ApplicationJob
  queue_as :default

  def perform(from:, to:, as_of: Time.current.utc)
    MarketData::Importer.new.call(
      from: parse_time(from),
      to: parse_time(to),
      as_of: parse_time(as_of)
    )
  end

  private
    def parse_time(value)
      return value if value.is_a?(Time) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)

      Time.zone.parse(value.to_s)&.utc || Time.iso8601(value.to_s)
    end
end
