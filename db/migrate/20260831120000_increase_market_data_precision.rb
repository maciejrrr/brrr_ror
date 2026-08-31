class IncreaseMarketDataPrecision < ActiveRecord::Migration[8.1]
  MARKET_DATA_COLUMNS = %i[ open high low close volume ].freeze
  TRADE_PRICE_COLUMNS = %i[ entry_price exit_price ].freeze

  def up
    MARKET_DATA_COLUMNS.each do |column|
      change_column :price_bars, column, :decimal, precision: 38, scale: 18
    end

    TRADE_PRICE_COLUMNS.each do |column|
      change_column :backtest_trades, column, :decimal, precision: 38, scale: 18
    end
  end

  def down
    MARKET_DATA_COLUMNS.each do |column|
      change_column :price_bars, column, :decimal, precision: 30, scale: 10
    end

    TRADE_PRICE_COLUMNS.each do |column|
      change_column :backtest_trades, column, :decimal, precision: 30, scale: 10
    end
  end
end
