class BacktestRunsController < ApplicationController
  before_action :set_form_dependencies, only: %i[index new create]

  def index
    @runs = Current.user.backtest_runs.includes(:asset).filter_by(params).limit(50)
  end

  def new
    @backtest_run = Current.user.backtest_runs.build(asset: @assets.first)
    if @assets.first.present?
      bars_scope = @assets.first.price_bars.one_day
      earliest = bars_scope.chronological.pick(:open_time)
      latest = bars_scope.latest_first.pick(:open_time)
      if earliest && latest
        @backtest_run.from_time = [ latest - 1.year, earliest ].max.beginning_of_day.utc
        @backtest_run.to_time = latest.end_of_day.utc
      end
    end
  end

  def create
    @backtest_run = Current.user.backtest_runs.build(backtest_run_params)
    @backtest_run.resolved_parameters = strategy_parameters

    if @backtest_run.save
      BacktestExecutionJob.perform_later(@backtest_run.id)
      redirect_to @backtest_run, notice: "Backtest run queued."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @backtest_run = Current.user.backtest_runs.includes(:asset, :backtest_trades).find(params[:id])
    @trades = @backtest_run.backtest_trades.chronological.limit(200)
  end

  def destroy
    @backtest_run = Current.user.backtest_runs.find(params[:id])
    @backtest_run.destroy
    redirect_to backtest_runs_path, notice: "Backtest run deleted."
  end

  private
    def set_form_dependencies
      @assets = Asset.alphabetical
      @strategies = Backtest::Strategies.list
      @asset_date_bounds = PriceBar.group(:asset_id).pluck(:asset_id, Arel.sql("MIN(open_time)"), Arel.sql("MAX(open_time)")).to_h do |id, min_t, max_t|
        [ id, { min: min_t&.strftime("%Y-%m-%d"), max: [ max_t, Time.current.utc ].compact.min&.strftime("%Y-%m-%d") } ]
      end
    end

    def backtest_run_params
      params.require(:backtest_run).permit(
        :asset_id, :interval, :strategy_key, :starting_capital,
        :fee_percentage, :slippage_percentage, :label,
        :from_time, :to_time
      ).tap do |attributes|
        attributes[:from_time] = Time.zone.parse(attributes[:from_time].to_s)&.beginning_of_day&.utc if attributes[:from_time].present?
        attributes[:to_time] = Time.zone.parse(attributes[:to_time].to_s)&.end_of_day&.utc if attributes[:to_time].present?
      end
    end

    def strategy_parameters
      raw = params.dig(:backtest_run, :parameters)
      return {} if raw.blank?

      raw.permit(*Backtest::Strategies.parameter_keys).to_h
    end
end
