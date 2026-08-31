# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_31_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "price_provider"
    t.string "price_provider_symbol"
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol"], name: "index_assets_on_symbol", unique: true
  end

  create_table "backtest_runs", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.integer "bar_count"
    t.float "benchmark_cagr_percentage"
    t.float "benchmark_maximum_drawdown_percentage"
    t.float "cagr_percentage"
    t.datetime "created_at", null: false
    t.boolean "demo_data", default: false, null: false
    t.jsonb "equity_curve", default: [], null: false
    t.text "error_message"
    t.float "exposure_percentage"
    t.decimal "fee_percentage", precision: 10, scale: 6, null: false
    t.float "final_equity"
    t.datetime "from_time", null: false
    t.integer "interval", null: false
    t.string "label"
    t.float "maximum_drawdown_percentage"
    t.jsonb "resolved_parameters", default: {}, null: false
    t.float "sharpe_ratio"
    t.decimal "slippage_percentage", precision: 10, scale: 6, null: false
    t.decimal "starting_capital", precision: 20, scale: 2, null: false
    t.integer "status", default: 0, null: false
    t.string "strategy_key", null: false
    t.datetime "to_time", null: false
    t.float "total_return_percentage"
    t.integer "trade_count"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.float "win_rate_percentage"
    t.index ["asset_id", "strategy_key", "created_at"], name: "idx_on_asset_id_strategy_key_created_at_265fb49ee1"
    t.index ["asset_id"], name: "index_backtest_runs_on_asset_id"
    t.index ["user_id", "created_at"], name: "index_backtest_runs_on_user_id_and_created_at"
    t.index ["user_id", "status", "created_at"], name: "index_backtest_runs_on_user_id_and_status_and_created_at"
    t.index ["user_id"], name: "index_backtest_runs_on_user_id"
  end

  create_table "backtest_trades", force: :cascade do |t|
    t.bigint "backtest_run_id", null: false
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 38, scale: 18, null: false
    t.datetime "entry_time", null: false
    t.decimal "exit_price", precision: 38, scale: 18
    t.datetime "exit_time"
    t.integer "holding_bars", null: false
    t.boolean "open_position", default: false, null: false
    t.float "return_percentage"
    t.datetime "updated_at", null: false
    t.index ["backtest_run_id"], name: "index_backtest_trades_on_backtest_run_id"
  end

  create_table "price_bars", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.decimal "close", precision: 38, scale: 18, null: false
    t.datetime "created_at", null: false
    t.integer "data_source", default: 1, null: false
    t.decimal "high", precision: 38, scale: 18, null: false
    t.integer "interval", null: false
    t.decimal "low", precision: 38, scale: 18, null: false
    t.decimal "open", precision: 38, scale: 18, null: false
    t.datetime "open_time", null: false
    t.datetime "updated_at", null: false
    t.decimal "volume", precision: 38, scale: 18, null: false
    t.index ["asset_id", "interval", "open_time"], name: "index_price_bars_on_asset_id_and_interval_and_open_time", unique: true
    t.index ["asset_id"], name: "index_price_bars_on_asset_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email_address)::text)", name: "index_users_on_lower_email_address", unique: true
  end

  add_foreign_key "backtest_runs", "assets"
  add_foreign_key "backtest_runs", "users"
  add_foreign_key "backtest_trades", "backtest_runs"
  add_foreign_key "price_bars", "assets"
  add_foreign_key "sessions", "users", on_delete: :cascade
end
