class AssetsController < ApplicationController
  def index
    @assets = Asset.alphabetical
  end

  def show
    @asset = Asset.find_by(symbol: params[:id].to_s.upcase) || Asset.find(params[:id])
    @interval = params[:interval].presence_in(%w[one_day one_hour]) || @asset.supported_intervals.first || "one_day"

    bars_scope = @asset.price_bars.for_interval(@interval)
    latest_open = bars_scope.latest_first.pick(:open_time)
    window = PriceBar.time_window(latest_open, interval: @interval, from: params[:from], to: params[:to])

    @from_time = window.begin
    @to_time = window.end
    @bars = bars_scope.between(@from_time, @to_time).chronological.to_a
    @latest_bar = bars_scope.latest_first.first
    @first_bar = bars_scope.chronological.first
    @total_bars = bars_scope.count
    @chart_data = @bars.map(&:as_chart_point)
  end
end
