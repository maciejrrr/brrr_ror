require "test_helper"

class PriceBarTest < ActiveSupport::TestCase
  test "keeps exact decimal values" do
    bar = price_bars(:btc_hour)

    assert_instance_of BigDecimal, bar.open
    assert_equal BigDecimal("45000.1234567890"), bar.open
    assert_equal BigDecimal("1234.1234567890"), bar.volume
  end

  test "orders and bounds candles by UTC opening instant" do
    bars = assets(:spy).price_bars.one_day
      .between(Time.utc(2024, 1, 2), Time.utc(2024, 1, 3))
      .chronological

    assert_equal [ price_bars(:spy_day_one), price_bars(:spy_day_two) ], bars
  end

  test "rejects duplicate series keys" do
    duplicate = price_bars(:spy_day_one).dup

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:open_time, :taken)
  end

  test "rejects incoherent OHLC values" do
    bar = price_bars(:spy_day_one)
    bar.high = bar.close - 1

    assert_not bar.valid?
    assert_includes bar.errors[:base], "OHLC values are not coherent"
  end

  test "rejects timestamps that do not align to the interval" do
    bar = price_bars(:btc_hour)
    bar.open_time += 1.minute

    assert_not bar.valid?
    assert_includes bar.errors[:open_time], "must align to the candle interval in UTC"
  end

  test "database session and candle columns use UTC-aware timestamps" do
    connection = ActiveRecord::Base.connection
    open_time_column = connection.columns(:price_bars).find { |column| column.name == "open_time" }

    assert_equal "UTC", connection.select_value("SHOW TIMEZONE")
    assert_equal "timestamp(6) with time zone", open_time_column.sql_type
  end

  test "stores market data with crypto-grade decimal precision" do
    connection = ActiveRecord::Base.connection
    open_column = connection.columns(:price_bars).find { |column| column.name == "open" }

    assert_equal 38, open_column.precision
    assert_equal 18, open_column.scale
  end
end
