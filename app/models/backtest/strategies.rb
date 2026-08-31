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
          params[name] = parse_and_validate_param(name, value)
        end
      end
    end

    def parse_and_validate_param(name, raw_value)
      value = parse_numeric_value(raw_value)
      is_period = name.to_s.end_with?("_period", "_bars") || name.to_s == "period"
      if is_period
        raise InvalidStrategyParameters, "Parameter #{name.inspect} must be a positive integer" unless value.is_a?(Integer) && value.positive?
      else
        raise InvalidStrategyParameters, "Parameter #{name.inspect} must be a non-negative number" unless value.is_a?(Numeric) && value.finite? && value >= 0
      end
      value
    end
    private_class_method :parse_and_validate_param

    def parse_numeric_value(value)
      if value.is_a?(String) && value.strip =~ /\A[+-]?\d+(?:\.\d+)?\z/
        value.include?(".") ? value.to_f : value.to_i
      else
        value
      end
    end
    private_class_method :parse_numeric_value

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

        donchian_step(candles[index], in_position, highs[index - 1], lows[index - 1])
      end
    end
    private_class_method :donchian

    def donchian_step(candle, in_position, previous_high, previous_low)
      if !in_position && previous_high && candle.close.to_f >= previous_high
        true
      elsif in_position && previous_low && candle.close.to_f <= previous_low
        false
      else
        in_position
      end
    end
    private_class_method :donchian_step

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

        mean_reversion_step(candles[index], in_position, average[index], ranges[index], params["atr_mult"])
      end
    end
    private_class_method :mean_reversion

    def mean_reversion_step(candle, in_position, average, range, mult)
      if !in_position && candle.close.to_f < average - mult * range
        true
      elsif in_position && candle.close.to_f >= average
        false
      else
        in_position
      end
    end
    private_class_method :mean_reversion_step

    def volatility_target(candles, params, bars_per_year)
      volatility = Indicators.realized_volatility(values: closes(candles), period: params["period"].to_i, bars_per_year: bars_per_year)
      volatility.map { |value| value.nil? || value.zero? ? 0.0 : [ 1.0, params["target_vol_pct"] / value ].min }
    end
    private_class_method :volatility_target

    def wyckoff_accumulation(candles, params, _bars)
      series = wyckoff_indicators(candles, params)
      spring_idx = -1
      in_position = false

      candles.each_index.map do |idx|
        in_position, spring_idx = wyckoff_step(candles[idx], idx, series, params, in_position, spring_idx)
        in_position ? 1.0 : 0.0
      end
    end
    private_class_method :wyckoff_accumulation

    def wyckoff_indicators(candles, params)
      {
        highs: Indicators.rolling_max(candles.map { |c| c.high.to_f }, params["range_period"].to_i),
        lows: Indicators.rolling_min(candles.map { |c| c.low.to_f }, params["range_period"].to_i),
        vol: Indicators.sma(candles.map { |c| c.volume.to_f }, params["vol_avg_period"].to_i),
        exit_lows: Indicators.rolling_min(candles.map { |c| c.low.to_f }, params["exit_period"].to_i)
      }
    end
    private_class_method :wyckoff_indicators

    def wyckoff_step(candle, idx, series, params, in_pos, spring_idx)
      return [ in_pos, spring_idx ] unless idx.positive? && series[:highs][idx - 1] && series[:lows][idx - 1] && series[:vol][idx - 1]

      spring_idx = idx if spring_condition?(candle, series, params, idx - 1)
      in_pos, spring_idx = evaluate_wyckoff_position(candle, idx, series, params, in_pos, spring_idx)
      [ in_pos, spring_idx ]
    end
    private_class_method :wyckoff_step

    def spring_condition?(candle, series, params, prev_idx)
      h = series[:highs][prev_idx]
      l = series[:lows][prev_idx]
      width = (h - l) / l * 100
      width <= params["range_max_width_pct"] &&
        candle.low.to_f < l && candle.close.to_f > l &&
        candle.volume.to_f >= series[:vol][prev_idx] * params["spring_vol_mult"]
    end
    private_class_method :spring_condition?

    def evaluate_wyckoff_position(candle, idx, series, params, in_pos, spring_idx)
      prev_idx = idx - 1
      if !in_pos && spring_idx >= 0 && idx - spring_idx <= params["sos_window_bars"] &&
         candle.close.to_f > series[:highs][prev_idx] && candle.volume.to_f >= series[:vol][prev_idx] * params["sos_vol_mult"]
        [ true, -1 ]
      elsif in_pos && series[:exit_lows][prev_idx] && candle.close.to_f < series[:exit_lows][prev_idx]
        [ false, spring_idx ]
      else
        [ in_pos, spring_idx ]
      end
    end
    private_class_method :evaluate_wyckoff_position

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
