# brrr

Market-data ingestion and quantitative strategy backtesting application. It imports historical OHLCV price candles, renders interactive charts, runs lookahead-free strategy simulations, and benchmarks performance against Buy & Hold.

---

## Features

- **Historical Feeds**: Ingestion from Binance (crypto hourly/daily) and Yahoo Finance (US equities daily) with exact decimal precision and UTC alignment.
- **Simulation Engine**: Lookahead-free backtesting where signals generated on bar $i$ execute on bar $i+1$ Open price, with customizable trading fees, slippage, and rebalance thresholds.
- **Strategy Presets**:
  - `buy_hold`: Benchmark baseline
  - `donchian`: Donchian channel breakout
  - `sma_trend`: Simple Moving Average trend filter with band tolerance
  - `ma_cross`: Fast / Slow moving average crossover
  - `mean_reversion`: Wilder RSI oversold/overbought bounce
  - `volatility_target`: Dynamic position sizing based on realized volatility
  - `wyckoff_accumulation`: Range breakout with volume confirmation
- **Performance Analytics**: Equity curve charts, CAGR vs Benchmark CAGR, Maximum Drawdown, Sharpe Ratio, Market Exposure %, Win Rate, and complete trade attribution logs.
- **Interactive Charts**: Responsive TradingView Lightweight Charts for both candlestick price action and equity growth curves.

---

## Getting Started

### Prerequisites

- Ruby 4.0.6
- PostgreSQL 14+
- Redis 6+

### Setup

1. **Clone the repository and install dependencies**:
   ```bash
   git clone git@github.com:maciejrrr/brrr_ror.git
   cd brrr_ror
   bundle install
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   ```

3. **Initialize database and offline demo data**:
   ```bash
   bin/rails db:prepare
   bin/rails db:seed
   ```
   *The seed script runs completely offline and sets up demo assets (SPY, BTC, ETH) and sample backtests.*

4. **Start the application**:
   ```bash
   bin/dev
   ```
   Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## Demo Account

- **Email**: `demo@example.com`
- **Password**: `password123`

---

## Testing & Quality

```bash
# Run test suite
bin/rails test

# Run linter
bin/rubocop

# Security audit
bin/brakeman --no-pager
bin/bundler-audit
```

---

## License

MIT
