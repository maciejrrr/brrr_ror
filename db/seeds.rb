# frozen_string_literal: true

puts "== Seeding demo user =="
demo_user = User.find_or_create_by!(email_address: "demo@example.com") do |u|
  u.password = "password123"
end

puts "== Seeding assets =="
spy = Asset.find_or_initialize_by(symbol: "SPY")
spy.assign_attributes(
  name: "SPDR S&P 500 ETF Trust",
  price_provider: :yahoo_finance,
  price_provider_symbol: "SPY"
)
spy.save!

btc = Asset.find_or_initialize_by(symbol: "BTC")
btc.assign_attributes(
  name: "Bitcoin",
  price_provider: :binance,
  price_provider_symbol: "BTCUSDT"
)
btc.save!

eth = Asset.find_or_initialize_by(symbol: "ETH")
eth.assign_attributes(
  name: "Ethereum",
  price_provider: :binance,
  price_provider_symbol: "ETHUSDT"
)
eth.save!

puts "== Generating deterministic demo price bars =="
# Generator for deterministic synthetic price bars
def generate_deterministic_bars(asset, interval, start_time, count, base_price, volatility, trend)
  step = interval == :one_hour ? 1.hour : 1.day
  current_price = base_price.to_f
  rows = []

  count.times do |i|
    open_time = start_time + (i * step)

    # Deterministic pseudo-randomness using sinusoidal and hash formulas
    seed_val = (open_time.to_i ^ asset.id ^ (interval == :one_hour ? 1337 : 7331)) % 10_000
    random_factor = (seed_val - 5_000) / 5_000.0 # [-1.0, 1.0]
    drift = trend + (Math.sin(i * 0.05) * volatility * 0.5)
    pct_change = drift + (random_factor * volatility)

    open_p = current_price
    close_p = [ open_p * (1.0 + pct_change), 0.01 ].max

    high_extra = (seed_val % 100) / 100.0 * volatility * open_p
    low_extra = ((seed_val / 100) % 100) / 100.0 * volatility * open_p

    high_p = [ open_p, close_p ].max + high_extra
    low_p = [ [ open_p, close_p ].min - low_extra, 0.001 ].max

    volume_base = base_price * 1000.0
    volume_p = volume_base * (0.5 + ((seed_val % 500) / 500.0))

    rows << {
      asset_id: asset.id,
      interval: PriceBar.intervals[interval],
      data_source: PriceBar.data_sources[:demo],
      open_time: open_time,
      open: BigDecimal(open_p.to_s).round(4),
      high: BigDecimal(high_p.to_s).round(4),
      low: BigDecimal(low_p.to_s).round(4),
      close: BigDecimal(close_p.to_s).round(4),
      volume: BigDecimal(volume_p.to_s).round(4),
      created_at: Time.current.utc,
      updated_at: Time.current.utc
    }

    current_price = close_p
  end

  PriceBar.upsert_all(
    rows,
    unique_by: %i[asset_id interval open_time],
    update_only: %i[data_source open high low close volume]
  )
  puts "  Created/updated #{rows.length} #{interval} bars for #{asset.symbol}"
end

# SPY: Daily bars for 2024
spy_start = Time.utc(2024, 1, 1, 0, 0, 0)
generate_deterministic_bars(spy, :one_day, spy_start, 366, 470.0, 0.012, 0.0006)

# BTC: Daily bars for 2024 and hourly bars for the last 30 days
btc_start_day = Time.utc(2024, 1, 1, 0, 0, 0)
generate_deterministic_bars(btc, :one_day, btc_start_day, 366, 42000.0, 0.025, 0.0012)
btc_start_hour = Time.utc(2024, 12, 1, 0, 0, 0)
generate_deterministic_bars(btc, :one_hour, btc_start_hour, 744, 85000.0, 0.008, 0.0003)

# ETH: Daily bars for 2024 and hourly bars for the last 30 days
eth_start_day = Time.utc(2024, 1, 1, 0, 0, 0)
generate_deterministic_bars(eth, :one_day, eth_start_day, 366, 2200.0, 0.03, 0.001)
eth_start_hour = Time.utc(2024, 12, 1, 0, 0, 0)
generate_deterministic_bars(eth, :one_hour, eth_start_hour, 744, 3400.0, 0.01, 0.0002)

puts "== Seeding demo backtest runs =="
# 1. SPY Buy & Hold (completed)
run_spy_bh = BacktestRun.find_or_initialize_by(
  user: demo_user,
  asset: spy,
  strategy_key: "buy_hold",
  interval: :one_day,
  from_time: Time.utc(2024, 1, 1, 0, 0, 0),
  to_time: Time.utc(2024, 12, 31, 0, 0, 0)
)
run_spy_bh.assign_attributes(
  label: "SPY 2024 Buy & Hold Benchmark",
  starting_capital: 10_000.0,
  fee_percentage: 0.05,
  slippage_percentage: 0.02,
  status: :queued,
  demo_data: true
)
run_spy_bh.save!
BacktestExecutionJob.perform_now(run_spy_bh.id)
puts "  Executed: #{run_spy_bh.display_name} (Status: #{run_spy_bh.reload.status}, Return: #{run_spy_bh.total_return_percentage&.round(2)}%)"

# 2. BTC Donchian Breakout (completed)
run_btc_donchian = BacktestRun.find_or_initialize_by(
  user: demo_user,
  asset: btc,
  strategy_key: "donchian",
  interval: :one_day,
  from_time: Time.utc(2024, 1, 1, 0, 0, 0),
  to_time: Time.utc(2024, 12, 31, 0, 0, 0)
)
run_btc_donchian.assign_attributes(
  label: "BTC 2024 Donchian Trend",
  resolved_parameters: { "entry_period" => 20, "exit_period" => 10 },
  starting_capital: 25_000.0,
  fee_percentage: 0.1,
  slippage_percentage: 0.05,
  status: :queued,
  demo_data: true
)
run_btc_donchian.save!
BacktestExecutionJob.perform_now(run_btc_donchian.id)
puts "  Executed: #{run_btc_donchian.display_name} (Status: #{run_btc_donchian.reload.status}, Return: #{run_btc_donchian.total_return_percentage&.round(2)}%)"

# 3. ETH SMA Trend on hourly (completed)
run_eth_sma = BacktestRun.find_or_initialize_by(
  user: demo_user,
  asset: eth,
  strategy_key: "sma_trend",
  interval: :one_hour,
  from_time: Time.utc(2024, 12, 1, 0, 0, 0),
  to_time: Time.utc(2024, 12, 31, 0, 0, 0)
)
run_eth_sma.assign_attributes(
  label: "ETH Dec 2024 Hourly SMA Trend",
  resolved_parameters: { "period" => 48, "band_pct" => 2 },
  starting_capital: 10_000.0,
  fee_percentage: 0.1,
  slippage_percentage: 0.05,
  status: :queued,
  demo_data: true
)
run_eth_sma.save!
BacktestExecutionJob.perform_now(run_eth_sma.id)
puts "  Executed: #{run_eth_sma.display_name} (Status: #{run_eth_sma.reload.status}, Return: #{run_eth_sma.total_return_percentage&.round(2)}%)"

puts "== Seed complete =="
