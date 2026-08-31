class MarketDataImportJob < ApplicationJob
  queue_as :default

  def perform(from:, to:, as_of: Time.current.utc)
    MarketData::Importer.new.call(
      from: Time.iso8601(from.to_s),
      to: Time.iso8601(to.to_s),
      as_of: Time.iso8601(as_of.to_s)
    )
  end
end
