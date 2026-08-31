module Backtest
  class Engine
    MIN_REBALANCE_FRACTION = 0.005
    Result = Struct.new(:final_equity, :total_return_percentage, :cagr_percentage,
      :maximum_drawdown_percentage, :sharpe_ratio, :exposure_percentage,
      :trade_count, :win_rate_percentage, :trades, :equity_curve, keyword_init: true)
    Trade = Struct.new(:entry_time, :exit_time, :entry_price, :exit_price,
      :return_percentage, :holding_bars, :open_position, keyword_init: true)

    def self.run(**arguments)
      new(**arguments).run
    end

    def initialize(candles:, weights:, costs:, starting_capital:, bars_per_year:)
      @candles = candles
      @weights = weights
      @costs = costs
      @starting_capital = starting_capital.to_f
      @bars_per_year = bars_per_year.to_f
    end

    def run
      validate_input
      rate = fee_rate
      equity_curve, trades, bars_in_market = simulate_timeline(rate)
      metrics = summarize(equity_curve)

      Result.new(
        **metrics,
        exposure_percentage: bars_in_market * 100.0 / @candles.length,
        trade_count: trades.length,
        win_rate_percentage: win_rate(trades),
        trades:,
        equity_curve:
      )
    end

    private
      def fee_rate
        (cost_value(:fee_percentage, :fee_pct) + cost_value(:slippage_percentage, :slippage_pct)) / 100.0
      end

      def cost_value(primary_key, alias_key)
        val = @costs[primary_key] || @costs[primary_key.to_s] || @costs[alias_key] || @costs[alias_key.to_s] || 0.0
        val.to_f
      end

      def simulate_timeline(rate)
        state = { cash: @starting_capital, units: 0.0, bars_in_market: 0, open_trade: nil }
        equity_curve = []
        trades = []

        @candles.each_with_index do |candle, index|
          equity = state[:cash] + state[:units] * price(candle, :close)
          equity_curve << { time: candle.open_time, value: equity }
          state[:bars_in_market] += 1 if state[:units].positive?
          next if index + 1 >= @candles.length

          rebalance_step(state, index, rate, trades)
        end

        close_final_position(state, rate, trades)
        [ equity_curve, trades, state[:bars_in_market] ]
      end

      def rebalance_step(state, index, rate, trades)
        target = clamp(@weights[index])
        fill_price = price(@candles[index + 1], :open)
        equity_at_fill = state[:cash] + state[:units] * fill_price
        desired_notional = ((target * equity_at_fill) / fill_price - state[:units]) * fill_price
        return if desired_notional.abs <= equity_at_fill * MIN_REBALANCE_FRACTION

        if desired_notional.positive?
          execute_buy(state, desired_notional, fill_price, rate, index)
        else
          execute_sell(state, desired_notional, fill_price, rate, index, trades)
        end
      end

      def execute_buy(state, desired_notional, fill_price, rate, index)
        notional = [ desired_notional, state[:cash] / (1 + rate) ].min
        return unless notional.positive?

        state[:cash] -= notional * (1 + rate)
        state[:units] += notional / fill_price
        track_buy_trade(state, notional, fill_price, rate, index)
      end

      def track_buy_trade(state, notional, fill_price, rate, index)
        state[:open_trade] ||= {
          entry_time: @candles[index + 1].open_time,
          entry_price: fill_price,
          entry_index: index + 1,
          invested_cash: 0.0,
          returned_cash: 0.0,
          peak_capital: 0.0
        }
        state[:open_trade][:invested_cash] += notional * (1 + rate)
        state[:open_trade][:peak_capital] = [
          state[:open_trade][:peak_capital],
          state[:open_trade][:invested_cash] - state[:open_trade][:returned_cash]
        ].max
      end

      def execute_sell(state, desired_notional, fill_price, rate, index, trades)
        notional = -desired_notional
        state[:cash] += notional * (1 - rate)
        state[:units] -= notional / fill_price
        state[:units] = 0.0 if state[:units] < 1e-12
        return unless state[:open_trade]

        state[:open_trade][:returned_cash] += notional * (1 - rate)
        return unless state[:units].zero?

        trades << build_trade(
          state[:open_trade],
          exit_time: @candles[index + 1].open_time,
          exit_price: fill_price,
          exit_index: index + 1,
          liquidation_value: 0.0,
          open_position: false
        )
        state[:open_trade] = nil
      end

      def close_final_position(state, rate, trades)
        return unless state[:open_trade]

        last = @candles.last
        close_price = price(last, :close)
        trades << build_trade(
          state[:open_trade],
          exit_time: last.open_time,
          exit_price: close_price,
          exit_index: @candles.length - 1,
          liquidation_value: state[:units] * close_price * (1 - rate),
          open_position: true
        )
      end

      def validate_input
        validate_shapes_and_capital
        validate_costs
        validate_candle_series
      end

      def validate_shapes_and_capital
        raise ArgumentError, "weights length must match candles length" unless @weights.length == @candles.length
        raise ArgumentError, "A backtest needs at least 2 candles" if @candles.length < 2
        raise ArgumentError, "starting_capital must be positive and finite" unless @starting_capital.positive? && @starting_capital.finite?
        raise ArgumentError, "bars_per_year must be positive and finite" unless @bars_per_year.positive? && @bars_per_year.finite?
      end

      def validate_costs
        fee = cost_value(:fee_percentage, :fee_pct)
        slippage = cost_value(:slippage_percentage, :slippage_pct)
        valid = fee.finite? && slippage.finite? && fee >= 0 && slippage >= 0 && fee + slippage < 100
        raise ArgumentError, "costs must be finite and non-negative" unless valid
      end

      def validate_candle_series
        @candles.each_cons(2) do |previous, current|
          raise ArgumentError, "candles must be strictly increasing" unless current.open_time > previous.open_time
        end
        @candles.each do |candle|
          %i[ open high low close ].each do |field|
            val = price(candle, field)
            raise ArgumentError, "prices must be positive and finite" unless val.positive? && val.finite?
          end
        end
      end

      def price(candle, field)
        candle.public_send(field).to_f
      end

      def clamp(weight)
        value = weight.to_f
        return 0.0 unless value.finite?

        value.clamp(0.0, 1.0)
      end

      def build_trade(trade, exit_time:, exit_price:, exit_index:, liquidation_value:, open_position:)
        profit = trade[:returned_cash] + liquidation_value - trade[:invested_cash]
        return_pct = trade[:peak_capital].positive? ? (profit / trade[:peak_capital] * 100) : 0.0
        Trade.new(
          entry_time: trade[:entry_time],
          exit_time:,
          entry_price: trade[:entry_price],
          exit_price:,
          return_percentage: return_pct,
          holding_bars: exit_index - trade[:entry_index],
          open_position:
        )
      end

      def summarize(curve)
        final_equity = [ curve.last[:value], 0.0 ].max
        drawdown = calculate_drawdown(curve)
        sharpe = calculate_sharpe(curve)
        cagr = calculate_cagr(final_equity, curve.length)

        {
          final_equity:,
          total_return_percentage: (final_equity - @starting_capital) / @starting_capital * 100,
          cagr_percentage: cagr,
          maximum_drawdown_percentage: drawdown,
          sharpe_ratio: sharpe
        }
      end

      def calculate_drawdown(curve)
        peak = -Float::INFINITY
        drawdown = 0.0
        curve.each do |point|
          peak = point[:value] if point[:value] > peak
          drawdown = peak.positive? ? [ drawdown, (point[:value] - peak) / peak * 100 ].min : -100.0
        end
        drawdown
      end

      def calculate_sharpe(curve)
        returns = curve.each_cons(2).filter_map { |first, second| first[:value].positive? ? second[:value] / first[:value] - 1 : nil }
        return 0.0 if returns.empty?

        mean = returns.sum / returns.length
        variance = returns.length > 1 ? returns.sum { |v| (v - mean)**2 } / (returns.length - 1) : 0.0
        std_dev = Math.sqrt(variance)
        std_dev.positive? ? (mean / std_dev * Math.sqrt(@bars_per_year)) : 0.0
      end

      def calculate_cagr(final_equity, curve_length)
        years = (curve_length - 1) / @bars_per_year
        return 0.0 unless years.positive?
        return -100.0 if final_equity <= 0

        raw_cagr = ((final_equity / @starting_capital)**(1.0 / years) - 1.0) * 100.0
        raw_cagr.finite? ? raw_cagr : (final_equity > @starting_capital ? 100_000.0 : -100.0)
      end

      def win_rate(trades)
        closed = trades.reject(&:open_position)
        return 0.0 if closed.empty?

        closed.count { |trade| trade.return_percentage.to_f.positive? } * 100.0 / closed.length
      end
  end
end
