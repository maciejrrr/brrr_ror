class BacktestExecutionJob < ApplicationJob
  queue_as :default

  def perform(backtest_run_id)
    run = BacktestRun.find_by(id: backtest_run_id)
    return unless run&.queued?

    run.update!(status: :running)
    execute(run)
  rescue ActiveRecord::RecordInvalid => error
    Rails.logger.warn("Validation error during backtest execution #{backtest_run_id}: #{error.message}")
    run&.update_columns(status: BacktestRun.statuses[:failed], error_message: sanitize_error(error.message))
  rescue ActiveRecord::ActiveRecordError, PG::Error => error
    Rails.logger.error("Infrastructure ActiveRecord error executing backtest #{backtest_run_id}: #{error.message}")
    raise
  rescue StandardError => error
    Rails.logger.warn("Domain error executing backtest #{backtest_run_id}: #{error.message}")
    run&.update_columns(status: BacktestRun.statuses[:failed], error_message: sanitize_error(error.message))
  end

  private
    def execute(run)
      bars = load_bars(run)
      strategy_result = run_simulation(run, bars, strategy_key: run.strategy_key, params: run.resolved_parameters)
      benchmark_result = run_simulation(run, bars, strategy_key: "buy_hold", params: {})

      persist_results(run, strategy_result:, benchmark_result:, bars:)
    end

    def load_bars(run)
      bars = run.asset.price_bars.public_send(run.interval).between(run.from_time, run.to_time).chronological.to_a
      if bars.length < 2
        raise ArgumentError, "At least 2 price bars are required for the selected date range and interval"
      end

      bars
    end

    def run_simulation(run, bars, strategy_key:, params:)
      bars_per_year = run.interval == "one_hour" ? 8760 : 365
      costs = { fee_percentage: run.fee_percentage.to_f, slippage_percentage: run.slippage_percentage.to_f }

      strategy_output = Backtest::Strategies.build_weights(
        key: strategy_key,
        candles: bars,
        params:,
        bars_per_year:
      )

      Backtest::Engine.run(
        candles: bars,
        weights: strategy_output[:weights],
        costs:,
        starting_capital: run.starting_capital.to_f,
        bars_per_year:
      )
    end

    def persist_results(run, strategy_result:, benchmark_result:, bars:)
      is_demo = run.demo_data? || bars.any? { |b| b.respond_to?(:demo?) && b.demo? }
      display_curve = downsample_equity_curve(strategy_result.equity_curve)

      BacktestRun.transaction do
        run.backtest_trades.delete_all
        insert_trades(run, strategy_result.trades)

        run.update!(
          status: :completed,
          demo_data: is_demo,
          bar_count: bars.length,
          trade_count: strategy_result.trade_count,
          final_equity: strategy_result.final_equity,
          total_return_percentage: strategy_result.total_return_percentage,
          cagr_percentage: strategy_result.cagr_percentage,
          maximum_drawdown_percentage: strategy_result.maximum_drawdown_percentage,
          sharpe_ratio: strategy_result.sharpe_ratio,
          exposure_percentage: strategy_result.exposure_percentage,
          win_rate_percentage: strategy_result.win_rate_percentage,
          benchmark_cagr_percentage: benchmark_result.cagr_percentage,
          benchmark_maximum_drawdown_percentage: benchmark_result.maximum_drawdown_percentage,
          equity_curve: display_curve,
          error_message: nil
        )
      end
    end

    def insert_trades(run, trades)
      return if trades.empty?

      trades_attrs = trades.map do |trade|
        {
          backtest_run_id: run.id,
          entry_time: trade.entry_time,
          exit_time: trade.exit_time,
          entry_price: trade.entry_price,
          exit_price: trade.exit_price,
          return_percentage: trade.return_percentage,
          holding_bars: trade.holding_bars,
          open_position: trade.open_position,
          created_at: Time.current.utc,
          updated_at: Time.current.utc
        }
      end

      BacktestTrade.insert_all!(trades_attrs)
    end

    def downsample_equity_curve(curve, max_points: 500)
      return [] if curve.blank?
      return curve.map { |p| { "time" => p[:time].iso8601, "value" => p[:value].to_f.round(4) } } if curve.length <= max_points

      step = (curve.length - 1).to_f / (max_points - 1)
      indices = (0...max_points).map { |i| [ (i * step).round, curve.length - 1 ].min }.uniq
      indices.map do |index|
        point = curve[index]
        { "time" => point[:time].iso8601, "value" => point[:value].to_f.round(4) }
      end
    end

    def sanitize_error(message)
      message.to_s.gsub(/#<.*?>/, "").truncate(1_000)
    end
end
