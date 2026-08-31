class CreateResearchDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :assets do |t|
      t.string :symbol, null: false
      t.string :name, null: false
      t.integer :price_provider
      t.string :price_provider_symbol

      t.timestamps
    end

    add_index :assets, :symbol, unique: true

    create_table :price_bars do |t|
      t.references :asset, null: false, foreign_key: true
      t.integer :interval, null: false
      t.integer :data_source, null: false, default: 1
      t.datetime :open_time, null: false
      t.decimal :open, precision: 30, scale: 10, null: false
      t.decimal :high, precision: 30, scale: 10, null: false
      t.decimal :low, precision: 30, scale: 10, null: false
      t.decimal :close, precision: 30, scale: 10, null: false
      t.decimal :volume, precision: 30, scale: 10, null: false

      t.timestamps
    end

    add_index :price_bars, %i[ asset_id interval open_time ], unique: true

    create_table :backtest_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :interval, null: false
      t.string :strategy_key, null: false
      t.jsonb :resolved_parameters, null: false, default: {}
      t.string :label
      t.datetime :from_time, null: false
      t.datetime :to_time, null: false
      t.decimal :fee_percentage, precision: 10, scale: 6, null: false
      t.decimal :slippage_percentage, precision: 10, scale: 6, null: false
      t.decimal :starting_capital, precision: 20, scale: 2, null: false
      t.text :error_message
      t.boolean :demo_data, null: false, default: false
      t.integer :bar_count
      t.float :final_equity
      t.float :total_return_percentage
      t.float :cagr_percentage
      t.float :maximum_drawdown_percentage
      t.float :sharpe_ratio
      t.float :exposure_percentage
      t.integer :trade_count
      t.float :win_rate_percentage
      t.float :benchmark_cagr_percentage
      t.float :benchmark_maximum_drawdown_percentage
      t.jsonb :equity_curve, null: false, default: []

      t.timestamps
    end

    add_index :backtest_runs, %i[ user_id created_at ]
    add_index :backtest_runs, %i[ user_id status created_at ]
    add_index :backtest_runs, %i[ asset_id strategy_key created_at ]

    create_table :backtest_trades do |t|
      t.references :backtest_run, null: false, foreign_key: true
      t.datetime :entry_time, null: false
      t.datetime :exit_time
      t.decimal :entry_price, precision: 30, scale: 10, null: false
      t.decimal :exit_price, precision: 30, scale: 10
      t.float :return_percentage
      t.integer :holding_bars, null: false
      t.boolean :open_position, null: false, default: false

      t.timestamps
    end
  end
end
