module MarketData
  class ImportsController < ApplicationController
    def create
      from = if params[:from].present?
        Time.zone.parse(params[:from].to_s).beginning_of_day.utc.iso8601
      else
        30.days.ago.beginning_of_day.utc.iso8601
      end

      to = if params[:to].present?
        Time.zone.parse(params[:to].to_s).end_of_day.utc.iso8601
      else
        Time.current.utc.iso8601
      end

      MarketDataImportJob.perform_later(from: from, to: to)

      redirect_back fallback_location: root_path, notice: "Market data import job queued in background."
    end
  end
end
