class BacktestRunsController < ApplicationController
  def index
    @runs = Current.user.backtest_runs.includes(:asset).recent
    @runs = @runs.where(status: params[:status]) if params[:status].present?
    @runs = @runs.for_strategy(params[:strategy_key]) if params[:strategy_key].present?
    @runs = @runs.where(asset_id: params[:asset_id]) if params[:asset_id].present?
    @runs = @runs.limit(50)

    @assets = Asset.all.order(:symbol)
    @strategies = Backtest::Strategies.list
  end

  def new
    @assets = Asset.all.order(:symbol)
    @strategies = Backtest::Strategies.list
    @default_asset = @assets.first
    @backtest_run = Current.user.backtest_runs.build(
      asset: @default_asset,
      interval: :one_day,
      strategy_key: "buy_hold",
      from_time: 1.year.ago.beginning_of_day.utc,
      to_time: Time.current.utc,
      starting_capital: 10_000,
      fee_percentage: 0.05,
      slippage_percentage: 0.02
    )
  end

  def create
    @assets = Asset.all.order(:symbol)
    @strategies = Backtest::Strategies.list

    run_params = backtest_run_params
    parameters_params = params.dig(:backtest_run, :parameters)
    supplied_params = if parameters_params.present?
      parameters_params.permit(*Backtest::Strategies.parameter_keys).to_h
    else
      {}
    end

    @backtest_run = Current.user.backtest_runs.build(run_params)
    @backtest_run.resolved_parameters = supplied_params

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
    def backtest_run_params
      raw = params.require(:backtest_run).permit(
        :asset_id, :interval, :strategy_key, :starting_capital,
        :fee_percentage, :slippage_percentage, :label,
        :from_time, :to_time
      )

      if raw[:from_time].present?
        begin
          raw[:from_time] = Time.zone.parse(raw[:from_time].to_s).beginning_of_day.utc
        rescue StandardError
          nil
        end
      end
      if raw[:to_time].present?
        begin
          raw[:to_time] = Time.zone.parse(raw[:to_time].to_s).end_of_day.utc
        rescue StandardError
          nil
        end
      end
      raw
    end
end
