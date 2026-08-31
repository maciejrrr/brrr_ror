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
      fee = @costs[:fee_percentage] || @costs["fee_percentage"] || @costs[:fee_pct] || @costs["fee_pct"] || 0.0
      slippage = @costs[:slippage_percentage] || @costs["slippage_percentage"] || @costs[:slippage_pct] || @costs["slippage_pct"] || 0.0
      fee_rate = (fee.to_f + slippage.to_f) / 100.0
      cash = @starting_capital
      units = 0.0
      bars_in_market = 0
      equity_curve = []
      trades = []
      open_trade = nil

      @candles.each_with_index do |candle, index|
        equity = cash + units * price(candle, :close)
        equity_curve << { time: candle.open_time, value: equity }
        bars_in_market += 1 if units.positive?
        next if index + 1 >= @candles.length

        target = clamp(@weights[index])
        fill_price = price(@candles[index + 1], :open)
        equity_at_fill = cash + units * fill_price
        desired_notional = ((target * equity_at_fill) / fill_price - units) * fill_price
        next if desired_notional.abs <= equity_at_fill * MIN_REBALANCE_FRACTION

        if desired_notional.positive?
          notional = [ desired_notional, cash / (1 + fee_rate) ].min
          next unless notional.positive?

          cash -= notional * (1 + fee_rate)
          units += notional / fill_price
          open_trade ||= { entry_time: @candles[index + 1].open_time, entry_price: fill_price,
                           entry_index: index + 1, invested_cash: 0.0, returned_cash: 0.0, peak_capital: 0.0 }
          open_trade[:invested_cash] += notional * (1 + fee_rate)
          open_trade[:peak_capital] = [ open_trade[:peak_capital], open_trade[:invested_cash] - open_trade[:returned_cash] ].max
        else
          notional = -desired_notional
          cash += notional * (1 - fee_rate)
          units -= notional / fill_price
          units = 0.0 if units < 1e-12
          next unless open_trade

          open_trade[:returned_cash] += notional * (1 - fee_rate)
          next unless units.zero?

          trades << build_trade(open_trade, exit_time: @candles[index + 1].open_time,
            exit_price: fill_price, exit_index: index + 1, liquidation_value: 0.0, open_position: false)
          open_trade = nil
        end
      end

      if open_trade
        last = @candles.last
        trades << build_trade(open_trade, exit_time: last.open_time, exit_price: price(last, :close),
          exit_index: @candles.length - 1, liquidation_value: units * price(last, :close) * (1 - fee_rate), open_position: true)
      end

      metrics = summarize(equity_curve)
      Result.new(**metrics, exposure_percentage: bars_in_market * 100.0 / @candles.length,
        trade_count: trades.length, win_rate_percentage: win_rate(trades), trades:, equity_curve:)
    end

    private
      def validate_input
        raise ArgumentError, "weights length must match candles length" unless @weights.length == @candles.length
        raise ArgumentError, "A backtest needs at least 2 candles" if @candles.length < 2
        raise ArgumentError, "starting_capital must be positive and finite" unless @starting_capital.positive? && @starting_capital.finite?
        raise ArgumentError, "bars_per_year must be positive and finite" unless @bars_per_year.positive? && @bars_per_year.finite?
        fee = (@costs[:fee_percentage] || @costs["fee_percentage"] || @costs[:fee_pct] || @costs["fee_pct"] || 0.0).to_f
        slippage = (@costs[:slippage_percentage] || @costs["slippage_percentage"] || @costs[:slippage_pct] || @costs["slippage_pct"] || 0.0).to_f
        raise ArgumentError, "costs must be finite and non-negative" unless fee.finite? && slippage.finite? && fee >= 0 && slippage >= 0 && fee + slippage < 100

        @candles.each_cons(2) do |previous, current|
          raise ArgumentError, "candles must be strictly increasing" unless current.open_time > previous.open_time
        end
        @candles.each do |candle|
          %i[ open high low close ].each { |field| raise ArgumentError, "prices must be positive and finite" unless price(candle, field).positive? && price(candle, field).finite? }
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
        return_pct = if trade[:peak_capital].positive?
          profit / trade[:peak_capital] * 100
        else
          0.0
        end
        Trade.new(entry_time: trade[:entry_time], exit_time:, entry_price: trade[:entry_price], exit_price:,
          return_percentage: return_pct, holding_bars: exit_index - trade[:entry_index], open_position:)
      end

      def summarize(curve)
        final_equity = [ curve.last[:value], 0.0 ].max
        years = (curve.length - 1) / @bars_per_year
        peak = -Float::INFINITY
        drawdown = 0.0
        curve.each do |point|
          peak = point[:value] if point[:value] > peak
          if peak.positive?
            drawdown = [ drawdown, (point[:value] - peak) / peak * 100 ].min
          else
            drawdown = -100.0
          end
        end
        returns = curve.each_cons(2).filter_map { |first, second| first[:value].positive? ? second[:value] / first[:value] - 1 : nil }
        mean = returns.empty? ? 0.0 : returns.sum / returns.length
        variance = returns.length > 1 ? returns.sum { |value| (value - mean)**2 } / (returns.length - 1) : 0.0
        standard_deviation = Math.sqrt(variance)
        sharpe = standard_deviation.positive? ? mean / standard_deviation * Math.sqrt(@bars_per_year) : 0.0
        cagr = if years.positive?
          if final_equity <= 0
            -100.0
          else
            raw_cagr = ((final_equity / @starting_capital)**(1.0 / years) - 1.0) * 100.0
            raw_cagr.finite? ? raw_cagr : (final_equity > @starting_capital ? 100_000.0 : -100.0)
          end
        else
          0.0
        end
        { final_equity:, total_return_percentage: (final_equity - @starting_capital) / @starting_capital * 100,
          cagr_percentage: cagr, maximum_drawdown_percentage: drawdown, sharpe_ratio: sharpe }
      end

      def win_rate(trades)
        closed = trades.reject(&:open_position)
        return 0.0 if closed.empty?

        closed.count { |trade| trade.return_percentage.to_f.positive? } * 100.0 / closed.length
      end
  end
end
