class DashboardController < ApplicationController
  def index
    @assets_count = Asset.count
    @total_bars_count = PriceBar.count
    @backtests_count = Current.user.backtest_runs.count
    @recent_runs = Current.user.backtest_runs.includes(:asset).recent.limit(5)
    @assets = Asset.alphabetical
    @latest_bar = PriceBar.latest_first.first
  end
end
