module MarketData
  class ImportsController < ApplicationController
    def create
      range = MarketData::DateRange.parse(from: params[:from], to: params[:to])
      MarketDataImportJob.perform_later(from: range.from_iso8601, to: range.to_iso8601)

      redirect_back fallback_location: root_path, notice: "Market data import job queued in background."
    end
  end
end
