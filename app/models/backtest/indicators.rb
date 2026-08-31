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

      gains = 0.0
      losses = 0.0
      (1..period).each do |index|
        difference = values[index] - values[index - 1]
        difference >= 0 ? gains += difference : losses -= difference
      end
      average_gain = gains / period
      average_loss = losses / period
      output[period] = rsi_value(average_gain, average_loss)

      (period + 1...values.length).each do |index|
        difference = values[index] - values[index - 1]
        average_gain = (average_gain * (period - 1) + [ difference, 0 ].max) / period
        average_loss = (average_loss * (period - 1) + [ -difference, 0 ].max) / period
        output[index] = rsi_value(average_gain, average_loss)
      end
      output
    end

    def atr(candles, period = 14)
      assert_period(period)
      ranges = candles.each_with_index.map do |candle, index|
        next candle.high - candle.low if index.zero?

        previous_close = candles[index - 1].close
        [ candle.high - candle.low, (candle.high - previous_close).abs,
          (candle.low - previous_close).abs ].max
      end

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

      returns = values.each_with_index.map { |value, index| index.zero? ? 0.0 : value / values[index - 1] - 1 }
      output = Array.new(values.length)
      (period...values.length).each do |index|
        window = returns[(index - period + 1)..index]
        mean = window.sum / window.length
        variance = window.sum { |value| (value - mean)**2 } / (window.length - 1)
        output[index] = Math.sqrt(variance) * Math.sqrt(bars_per_year) * 100
      end
      output
    end

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
