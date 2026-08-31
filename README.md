# brrr · Quantitative Market Data & Trading Strategy Backtesting

`brrr` is a focused, production-grade Ruby on Rails monolith for market-data ingestion and long-only trading strategy research. It imports historical OHLCV candles, lets authenticated researchers inspect price charts, executes reproducible lookahead-safe strategy backtests, and benchmarks performance directly against buy-and-hold.

---

## Screenshots

| Research Dashboard | Asset Candlestick Chart |
| :---: | :---: |
| *(Dashboard KPI cards, market data assets, recent runs)* | *(TradingView Lightweight Charts, interval selector)* |

| Backtest Configuration | Performance & Equity Curve |
| :---: | :---: |
| *(Dynamic parameter builder per strategy)* | *(Interactive equity chart, metrics vs Buy & Hold, trade log)* |

---

## Key Features

- **Automated Market Data Feeds**:
  - Ingests hourly and daily crypto candles from Binance with forward pagination and duplicate suppression.
  - Ingests multi-decade daily US equity candles from Yahoo Finance.
  - Enforces strict UTC instant alignment (daily candles open at `00:00:00Z`).
  - Stores exact numeric values using PostgreSQL `numeric(38,18)` / Ruby `BigDecimal` (zero floating-point precision loss for prices and volume).
  - Overlaps and restates recent candles on subsequent imports to capture provider revisions.

- **Lookahead-Safe Backtesting Engine**:
  - Pure Ruby simulation engine independent of database and Rails layers.
  - Signals generated at bar $i$ close execute strictly at bar $i + 1$ open.
  - Realistic trading costs: fees and slippage charged on every fill.
  - Automatic portfolio rebalancing rules (skips changes $\le 0.5\%$ of equity).
  - Constrained long-only weights $[0, 1]$; strictly prevents negative cash, margin borrowing, or shorting.
  - Open positions at backtest window end are marked to market with closing costs and excluded from realized win rate.

- **Strategy Whitelist & Technical Indicators**:
  - Whitelisted strategies with typed parameter validation: `buy_hold`, `donchian`, `sma_trend`, `ma_cross`, `mean_reversion`, `volatility_target`, `wyckoff_accumulation`.
  - Optimized O(N) monotonic-deque rolling min/max, Wilder RSI, SMA, EMA, ATR, down streak, and annualized realized volatility.

- **Direct Benchmark Comparison**:
  - Every backtest automatically computes a Buy & Hold benchmark over the exact same candle window, capital, and cost parameters to provide context for alpha generation.

- **Modern Full-Stack Architecture**:
  - Server-rendered ERB views styled with Tailwind CSS.
  - Hotwire (Turbo) for background job progress polling and frame updates.
  - TradingView Lightweight Charts (v5) integrated through Importmap with zero bundler overhead.
  - Rails-native authentication and strict data scoping via `Current.user`.

---

## Tech Stack & Runtime

- **Ruby**: 4.0.6 (managed via asdf)
- **Ruby on Rails**: 8.1.3.1
- **Database**: PostgreSQL with `timestamptz` and database constraints
- **Background Jobs**: Sidekiq 8 with Redis (Active Job adapter)
- **Frontend**: Hotwire Turbo & Stimulus, Propshaft, Importmap, Tailwind CSS v4 (`tailwindcss-rails`)
- **Charts**: TradingView Lightweight Charts 5.2.1
- **Testing & Quality**: Rails Minitest, WebMock, RuboCop, Brakeman, Bundler Audit

---

## Architecture & Design

`brrr` is organized around clear domain boundaries and idiomatic Rails 8 conventions:

- **Active Record Domain Models**: Encapsulates persistence invariants, composite unique constraints, timestamp alignment checks, and strictly scoped associations.
- **Independent Simulation Engine**: Pure Ruby backtest engine operating on in-memory candle structures with zero lookahead and full transaction-cost modeling.
- **Strategy & Indicator Registry**: Typed strategy parameter validation and high-performance O(N) indicator functions (`SMA`, `EMA`, `Wilder RSI`, `ATR`, `Realized Volatility`, monotonic-deque rolling extrema).
- **Background Processing**: Sidekiq & Active Job coordinate asynchronous market data feeds and long-running backtest executions with atomic transactional result persistence.
- **Hotwire & Interactive Charts**: Server-rendered ERB layouts paired with Turbo drive polling and responsive TradingView Lightweight Charts (v5) without heavy client-side framework overhead.

---

## Getting Started

### Prerequisites

- Ruby `4.0.6`
- PostgreSQL 14+
- Redis 6+

### Environment Setup

Clone the repository and copy the template environment variables:

```bash
git clone <repository_url>
cd brrr_ror
cp .env.example .env
```

Ensure PostgreSQL and Redis are running locally.

### Database Setup & Deterministic Seeds

Prepare the database and load deterministic offline demo data:

```bash
bin/rails db:prepare
bin/rails db:seed
```

The seed script runs **completely offline** without calling third-party APIs. It populates:
- A demo user account (`demo@example.com` / `password123`)
- SPY (Yahoo Finance), BTC (Binance), and ETH (Binance) asset profiles
- Synthetic coherent OHLCV price bars across daily and hourly intervals
- Completed sample backtest runs with full trade attribution and benchmark metrics

### Starting the Development Server

Start Rails, Sidekiq, and the Tailwind watcher in one command:

```bash
bin/dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## Demo Credentials

- **Email**: `demo@example.com`
- **Password**: `password123`

---

## Market Data Ingestion

To backfill or update live candles from Binance and Yahoo Finance:

1. Click the **"Sync Data"** button in the navigation header, or
2. Enqueue the Active Job in Rails console / runner:

```ruby
# Ingest the last 30 days of data across all configured assets:
MarketDataImportJob.perform_later(
  from: 30.days.ago.beginning_of_day.utc.iso8601,
  to: Time.current.utc.iso8601
)
```

---

## Verification & Quality Assurance

Run the comprehensive suite of tests and security scanners:

```bash
# Run all unit, functional, and integration tests
bin/rails test

# Static code analysis and linting (0 offenses)
bin/rubocop

# Security vulnerability audit (0 warnings)
bin/brakeman --no-pager

# Dependency vulnerability audit
bin/bundler-audit

# Autoloading & eager loading verification
bin/rails zeitwerk:check

# Production Tailwind CSS asset compilation
bin/rails tailwindcss:build
```

---

## Important Disclaimers & Limitations

1. **Research Software**: `brrr` is built strictly for quantitative research, backtesting, and portfolio simulation. It does not execute live broker orders, manage real capital, or provide financial advice.
2. **Historical Provider Feeds**: Public endpoints (Binance and Yahoo Finance) may rate-limit or revise historical data. The application handles retries and late revisions idempotently.
3. **No Shorting or Leverage**: The backtesting engine enforces a strict long-only cash model without borrowing or margin.

---

## License

MIT License.
