class Asset < ApplicationRecord
  enum :price_provider, { yahoo_finance: 0, binance: 1 }, validate: { allow_nil: true }

  has_many :price_bars, dependent: :destroy
  has_many :backtest_runs, dependent: :restrict_with_error

  normalizes :symbol, with: ->(symbol) { symbol.strip.upcase }
  normalizes :price_provider_symbol, with: ->(symbol) { symbol&.strip&.upcase }

  validates :symbol, presence: true, uniqueness: true
  validates :name, presence: true
  validate :provider_configuration_is_paired
  validate :provider_configuration_is_immutable, on: :update

  scope :alphabetical, -> { order(:symbol) }

  def supported_intervals
    return %w[ one_day ] if yahoo_finance?
    return %w[ one_hour one_day ] if binance?

    []
  end

  private
    def provider_configuration_is_paired
      provider_present = price_provider.present?
      symbol_present = price_provider_symbol.present?
      return if provider_present == symbol_present

      errors.add(:price_provider, "and provider symbol must both be present or both be absent")
    end

    def provider_configuration_is_immutable
      changed = will_save_change_to_price_provider? || will_save_change_to_price_provider_symbol?
      return unless changed && price_bars.exists?

      errors.add(:price_provider, "cannot change after price bars have been imported")
    end
end
