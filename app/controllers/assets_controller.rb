class AssetsController < ApplicationController
  before_action :set_asset, only: :show
  before_action :set_interval, only: :show

  def index
    @assets = Asset.alphabetical
  end

  def show
    bars_scope = @asset.price_bars.for_interval(@interval)
    set_window_and_bars(bars_scope)
    set_summary_stats(bars_scope)
  end

  private
    def set_asset
      @asset = Asset.find_by(symbol: params[:id].to_s.upcase)
      return if @asset

      if params[:id].to_s.match?(/\A\d+\z/)
        @asset = Asset.find_by(id: params[:id])
      end

      raise ActiveRecord::RecordNotFound, "Couldn't find Asset with 'id'=#{params[:id]}" unless @asset
    end

    def set_interval
      @interval = params[:interval].presence_in(%w[one_day one_hour]) || @asset.supported_intervals.first || "one_day"
    end

    def set_window_and_bars(bars_scope)
      latest_open = bars_scope.latest_first.pick(:open_time)
      window = PriceBar.time_window(latest_open, interval: @interval, from: params[:from], to: params[:to])
      @from_time = window.begin
      @to_time = window.end
      @bars = bars_scope.between(@from_time, @to_time).chronological.to_a
      @chart_data = @bars.map(&:as_chart_point)
    end

    def set_summary_stats(bars_scope)
      @latest_bar = bars_scope.latest_first.first
      @first_bar = bars_scope.chronological.first
      @total_bars = bars_scope.count
    end
end
