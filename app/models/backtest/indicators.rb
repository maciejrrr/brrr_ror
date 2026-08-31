module Backtest
  module Indicators
    module_function

    def sma(values, period)
      assert_period(period)
      output = Array.new(values.length)
      sum = 0.0
      values.each_with_index do |value, index|
        sum += value
        sum -= values[index - period] if index >= period
        output[index] = sum / period if index >= period - 1
      end
      output
    end

    def ema(values, period)
      assert_period(period)
      output = Array.new(values.length)
      multiplier = 2.0 / (period + 1)
      previous = nil
      (period - 1...values.length).each do |index|
        previous = if previous.nil?
          values[(index - period + 1)..index].sum.to_f / period
        else
          values[index] * multiplier + previous * (1 - multiplier)
        end
        output[index] = previous
      end
      output
    end

    def rsi(values, period = 14)
      assert_period(period)
      output = Array.new(values.length)
      return output if values.length <= period

      avg_gain, avg_loss = initial_rsi_gains_losses(values, period)
      output[period] = rsi_value(avg_gain, avg_loss)
      populate_smoothed_rsi(values, period, avg_gain, avg_loss, output)
      output
    end

    def initial_rsi_gains_losses(values, period)
      gains = 0.0
      losses = 0.0
      (1..period).each do |index|
        diff = values[index] - values[index - 1]
        diff >= 0 ? gains += diff : losses -= diff
      end
      [ gains / period, losses / period ]
    end
    private_class_method :initial_rsi_gains_losses

    def populate_smoothed_rsi(values, period, avg_gain, avg_loss, output)
      (period + 1...values.length).each do |index|
        diff = values[index] - values[index - 1]
        avg_gain = (avg_gain * (period - 1) + [ diff, 0 ].max) / period
        avg_loss = (avg_loss * (period - 1) + [ -diff, 0 ].max) / period
        output[index] = rsi_value(avg_gain, avg_loss)
      end
    end
    private_class_method :populate_smoothed_rsi

    def atr(candles, period = 14)
      assert_period(period)
      ranges = compute_true_ranges(candles)
      output = Array.new(candles.length)
      previous = nil
      sum = 0.0
      ranges.each_with_index do |range, index|
        sum += range
        if index == period - 1
          previous = sum / period
        elsif index >= period
          previous = (previous * (period - 1) + range) / period
        end
        output[index] = previous
      end
      output
    end

    def compute_true_ranges(candles)
      candles.each_with_index.map do |candle, index|
        next candle.high - candle.low if index.zero?

        prev_close = candles[index - 1].close
        [ candle.high - candle.low, (candle.high - prev_close).abs, (candle.low - prev_close).abs ].max
      end
    end
    private_class_method :compute_true_ranges

    def rolling_max(values, period)
      rolling_extreme(values, period) { |candidate, incumbent| candidate >= incumbent }
    end

    def rolling_min(values, period)
      rolling_extreme(values, period) { |candidate, incumbent| candidate <= incumbent }
    end

    def realized_volatility(values:, period:, bars_per_year:)
      assert_period(period)
      raise ArgumentError, "Volatility needs a period of at least 2" if period < 2
      raise ArgumentError, "bars_per_year must be positive" unless bars_per_year.to_f.positive?

      returns = values.each_with_index.map { |v, idx| idx.zero? ? 0.0 : v / values[idx - 1] - 1 }
      output = Array.new(values.length)
      (period...values.length).each do |idx|
        window = returns[(idx - period + 1)..idx]
        output[idx] = window_volatility(window, bars_per_year)
      end
      output
    end

    def window_volatility(window, bars_per_year)
      mean = window.sum / window.length
      variance = window.sum { |value| (value - mean)**2 } / (window.length - 1)
      Math.sqrt(variance) * Math.sqrt(bars_per_year) * 100
    end
    private_class_method :window_volatility

    def down_streak(values)
      output = Array.new(values.length, 0)
      (1...values.length).each do |index|
        output[index] = values[index] < values[index - 1] ? output[index - 1] + 1 : 0
      end
      output
    end

    def assert_period(period)
      return if period.is_a?(Integer) && period.positive?

      raise ArgumentError, "Indicator period must be a positive integer, got #{period.inspect}"
    end
    private_class_method :assert_period

    def rsi_value(average_gain, average_loss)
      return 50.0 if average_gain.zero? && average_loss.zero?
      return 100.0 if average_loss.zero?

      100 - 100 / (1 + average_gain / average_loss)
    end
    private_class_method :rsi_value

    def rolling_extreme(values, period)
      assert_period(period)
      output = Array.new(values.length)
      deque = []
      values.each_with_index do |value, index|
        deque.pop while !deque.empty? && yield(value, values[deque.last])
        deque << index
        deque.shift if deque.first <= index - period
        output[index] = values[deque.first] if index >= period - 1
      end
      output
    end
    private_class_method :rolling_extreme
  end
end
