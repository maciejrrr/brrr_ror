module Backtest
  module Strategies
    Definition = Struct.new(:key, :description, :defaults, :builder, keyword_init: true)

    module_function

    def list
      registry.values
    end

    def parameter_keys
      registry.values.flat_map { |definition| definition.defaults.keys }.uniq
    end

    def fetch(key)
      registry.fetch(key.to_s) { raise UnknownStrategy, "Unknown strategy #{key.inspect}. Available: #{registry.keys.join(', ')}" }
    end

    def resolve(key, supplied = {})
      definition = fetch(key)
      supplied_hash = supplied.respond_to?(:to_unsafe_h) ? supplied.to_unsafe_h : (supplied || {}).to_h
      unknown = supplied_hash.keys.map(&:to_s) - definition.defaults.keys
      raise InvalidStrategyParameters, "Unknown parameter(s): #{unknown.join(', ')}" if unknown.any?

      definition.defaults.merge(supplied_hash.stringify_keys).tap do |params|
        params.each do |name, value|
          if value.is_a?(String) && value.strip =~ /\A[+-]?\d+(?:\.\d+)?\z/
            value = value.include?(".") ? value.to_f : value.to_i
            params[name] = value
          end
          is_period = name.to_s.end_with?("_period", "_bars") || name.to_s == "period"
          if is_period
            unless value.is_a?(Integer) && value.positive?
              raise InvalidStrategyParameters, "Parameter #{name.inspect} must be a positive integer"
            end
          else
            unless value.is_a?(Numeric) && value.finite? && value >= 0
              raise InvalidStrategyParameters, "Parameter #{name.inspect} must be a non-negative number"
            end
          end
        end
      end
    end

    def build_weights(key:, candles:, params: {}, bars_per_year:)
      definition = fetch(key)
      resolved = resolve(key, params)
      weights = definition.builder.call(candles, resolved, bars_per_year)
      raise InvalidStrategyParameters, "Strategy returned an invalid weight series" unless weights.length == candles.length && weights.all? { |weight| weight.is_a?(Numeric) && weight.finite? && weight.between?(0, 1) }

      { weights:, resolved_parameters: resolved }
    end

    def registry
      @registry ||= {
        "buy_hold" => Definition.new(key: "buy_hold", description: "Always fully invested", defaults: {}, builder: ->(candles, _params, _bars) { Array.new(candles.length, 1.0) }),
        "donchian" => Definition.new(key: "donchian", description: "Long on an N-bar high, flat on an M-bar low", defaults: { "entry_period" => 168, "exit_period" => 84 }, builder: method(:donchian)),
        "sma_trend" => Definition.new(key: "sma_trend", description: "Long above a moving average with hysteresis", defaults: { "period" => 200, "band_pct" => 5 }, builder: method(:sma_trend)),
        "ma_cross" => Definition.new(key: "ma_cross", description: "Long while a fast average exceeds a slow average", defaults: { "fast_period" => 72, "slow_period" => 720 }, builder: method(:ma_cross)),
        "mean_reversion" => Definition.new(key: "mean_reversion", description: "Long below a moving average and exit on recovery", defaults: { "sma_period" => 168, "atr_period" => 24, "atr_mult" => 2 }, builder: method(:mean_reversion)),
        "volatility_target" => Definition.new(key: "volatility_target", description: "Size exposure toward a volatility target", defaults: { "period" => 20, "target_vol_pct" => 60 }, builder: method(:volatility_target)),
        "wyckoff_accumulation" => Definition.new(key: "wyckoff_accumulation", description: "Spring and sign-of-strength accumulation", defaults: { "range_period" => 60, "range_max_width_pct" => 30, "vol_avg_period" => 60, "spring_vol_mult" => 1.5, "sos_vol_mult" => 1.3, "sos_window_bars" => 30, "exit_period" => 40 }, builder: method(:wyckoff_accumulation))
      }
    end
    private_class_method :registry

    def closes(candles)
      candles.map { |candle| candle.close.to_f }
    end
    private_class_method :closes

    def donchian(candles, params, _bars)
      highs = Indicators.rolling_max(candles.map { |c| c.high.to_f }, params["entry_period"].to_i)
      lows = Indicators.rolling_min(candles.map { |c| c.low.to_f }, params["exit_period"].to_i)
      stateful_weights(candles) do |index, in_position|
        next in_position if index.zero?
        if !in_position && highs[index - 1] && candles[index].close.to_f >= highs[index - 1]
          true
        elsif in_position && lows[index - 1] && candles[index].close.to_f <= lows[index - 1]
          false
        else
          in_position
        end
      end
    end
    private_class_method :donchian

    def sma_trend(candles, params, _bars)
      average = Indicators.sma(closes(candles), params["period"].to_i)
      in_position = false
      candles.each_with_index.map do |candle, index|
        value = average[index]
        if value
          in_position = true if candle.close.to_f > value * (1 + params["band_pct"] / 100.0)
          in_position = false if candle.close.to_f < value * (1 - params["band_pct"] / 100.0)
        end
        in_position ? 1.0 : 0.0
      end
    end
    private_class_method :sma_trend

    def ma_cross(candles, params, _bars)
      fast = Indicators.sma(closes(candles), params["fast_period"].to_i)
      slow = Indicators.sma(closes(candles), params["slow_period"].to_i)
      candles.each_index.map { |index| fast[index] && slow[index] && fast[index] > slow[index] ? 1.0 : 0.0 }
    end
    private_class_method :ma_cross

    def mean_reversion(candles, params, _bars)
      average = Indicators.sma(closes(candles), params["sma_period"].to_i)
      ranges = Indicators.atr(candles, params["atr_period"].to_i)
      stateful_weights(candles) do |index, in_position|
        next in_position unless average[index] && ranges[index]
        if !in_position && candles[index].close.to_f < average[index] - params["atr_mult"] * ranges[index]
          true
        elsif in_position && candles[index].close.to_f >= average[index]
          false
        else
          in_position
        end
      end
    end
    private_class_method :mean_reversion

    def volatility_target(candles, params, bars_per_year)
      volatility = Indicators.realized_volatility(values: closes(candles), period: params["period"].to_i, bars_per_year: bars_per_year)
      volatility.map { |value| value.nil? || value.zero? ? 0.0 : [ 1.0, params["target_vol_pct"] / value ].min }
    end
    private_class_method :volatility_target

    def wyckoff_accumulation(candles, params, _bars)
      highs = Indicators.rolling_max(candles.map { |c| c.high.to_f }, params["range_period"].to_i)
      lows = Indicators.rolling_min(candles.map { |c| c.low.to_f }, params["range_period"].to_i)
      average_volume = Indicators.sma(candles.map { |c| c.volume.to_f }, params["vol_avg_period"].to_i)
      exit_lows = Indicators.rolling_min(candles.map { |c| c.low.to_f }, params["exit_period"].to_i)
      spring_index = -1
      in_position = false
      candles.each_index.map do |index|
        if index.positive? && highs[index - 1] && lows[index - 1] && average_volume[index - 1]
          width = (highs[index - 1] - lows[index - 1]) / lows[index - 1] * 100
          if width <= params["range_max_width_pct"] && candles[index].low.to_f < lows[index - 1] && candles[index].close.to_f > lows[index - 1] && candles[index].volume.to_f >= average_volume[index - 1] * params["spring_vol_mult"]
            spring_index = index
          end
          if !in_position && spring_index >= 0 && index - spring_index <= params["sos_window_bars"] && candles[index].close.to_f > highs[index - 1] && candles[index].volume.to_f >= average_volume[index - 1] * params["sos_vol_mult"]
            in_position = true
            spring_index = -1
          elsif in_position && exit_lows[index - 1] && candles[index].close.to_f < exit_lows[index - 1]
            in_position = false
          end
        end
        in_position ? 1.0 : 0.0
      end
    end
    private_class_method :wyckoff_accumulation

    def stateful_weights(candles)
      in_position = false
      candles.each_index.map do |index|
        in_position = yield(index, in_position)
        in_position ? 1.0 : 0.0
      end
    end
    private_class_method :stateful_weights
  end
end
