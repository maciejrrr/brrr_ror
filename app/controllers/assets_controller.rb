class AssetsController < ApplicationController
  def index
    @assets = Asset.all.order(:symbol)
  end

  def show
    @asset = Asset.find_by(symbol: params[:id].to_s.upcase) || Asset.find(params[:id])
    @interval = params[:interval].presence_in(%w[one_day one_hour]) || @asset.supported_intervals.first || "one_day"

    bars_scope = @asset.price_bars.public_send(@interval)
    latest_open = bars_scope.latest_first.pick(:open_time) || Time.current.utc

    @to_time = if params[:to].present?
      Time.zone.parse(params[:to]).end_of_day.utc
    else
      latest_open.end_of_day.utc
    end

    @from_time = if params[:from].present?
      Time.zone.parse(params[:from]).beginning_of_day.utc
    else
      earliest_open = bars_scope.chronological.pick(:open_time) || latest_open
      default_window_start = latest_open - (@interval == "one_hour" ? 30.days : 365.days)
      [ default_window_start, earliest_open ].max.beginning_of_day.utc
    end

    @bars = bars_scope.between(@from_time, @to_time).chronological.to_a
    @latest_bar = bars_scope.latest_first.first
    @first_bar = bars_scope.chronological.first
    @total_bars = bars_scope.count

    @chart_data = @bars.map do |bar|
      {
        time: bar.open_time.to_i,
        open: bar.open.to_f,
        high: bar.high.to_f,
        low: bar.low.to_f,
        close: bar.close.to_f,
        volume: bar.volume.to_f
      }
    end
  end
end
