module MarketData
  class Importer
    PROVIDERS = {
      "binance" => Binance,
      "yahoo_finance" => YahooFinance
    }.freeze

    def initialize(provider_registry: {})
      @provider_registry = provider_registry
    end

    def call(from:, to:, as_of: Time.current.utc)
      result = { assets_imported: 0, assets_failed: 0, bars_upserted: 0 }

      Asset.where.not(price_provider: nil).find_each do |asset|
        begin
          bars = import_asset(asset, from: from, to: to, as_of: as_of)
          result[:assets_imported] += 1
          result[:bars_upserted] += bars
        rescue ActiveRecord::ActiveRecordError
          raise
        rescue StandardError => error
          Rails.logger.warn("Market data import failed for #{asset.symbol}: #{error.message}")
          result[:assets_failed] += 1
        end
      end

      result
    end

    private
      def import_asset(asset, from:, to:, as_of:)
        provider = provider_for(asset)
        asset.supported_intervals.sum do |interval|
          candles = provider.fetch(
            symbol: asset.price_provider_symbol,
            interval:,
            from:, to:, as_of:
          )
          persist(asset, interval, candles)
        end
      end

      def provider_for(asset)
        @provider_registry.fetch(asset.price_provider) { PROVIDERS.fetch(asset.price_provider).new }
      end

      def persist(asset, interval, candles)
        rows = candles.map do |candle|
          price_bar = PriceBar.new(
            asset:, interval:, data_source: :provider,
            open_time: candle.open_time,
            open: candle.open, high: candle.high, low: candle.low,
            close: candle.close, volume: candle.volume
          )
          raise InvalidResponse, price_bar.errors.full_messages.to_sentence unless price_bar.valid?

          price_bar.attributes.slice("asset_id", "interval", "data_source", "open_time", "open", "high", "low", "close", "volume")
        end
        return 0 if rows.empty?

        PriceBar.upsert_all(rows, unique_by: %i[ asset_id interval open_time ], update_only: %i[ data_source open high low close volume ])
        rows.length
      end
  end
end
