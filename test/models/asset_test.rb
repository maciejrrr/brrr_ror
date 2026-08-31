require "test_helper"

class AssetTest < ActiveSupport::TestCase
  test "normalizes symbols and reports provider intervals" do
    asset = Asset.new(
      symbol: " eth ",
      name: "Ethereum",
      price_provider: :binance,
      price_provider_symbol: " ethusdt "
    )

    assert asset.valid?
    assert_equal "ETH", asset.symbol
    assert_equal "ETHUSDT", asset.price_provider_symbol
    assert_equal %w[ one_hour one_day ], asset.supported_intervals
  end

  test "requires provider and provider symbol together" do
    asset = Asset.new(symbol: "GLD", name: "Gold", price_provider: :yahoo_finance)

    assert_not asset.valid?
    assert_includes asset.errors[:price_provider],
      "and provider symbol must both be present or both be absent"
  end

  test "prevents changing the provider of a populated series" do
    asset = assets(:spy)
    asset.assign_attributes(price_provider: :binance, price_provider_symbol: "SPYUSDT")

    assert_not asset.valid?
    assert_includes asset.errors[:price_provider], "cannot change after price bars have been imported"
  end

  test "allows changing provider configuration before bars exist" do
    asset = assets(:unconfigured)
    asset.assign_attributes(price_provider: :yahoo_finance, price_provider_symbol: "TEST")

    assert asset.valid?
  end
end
