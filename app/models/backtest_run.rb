class BacktestRun < ApplicationRecord
  STRATEGY_KEYS = %w[
    buy_hold
    donchian
    sma_trend
    ma_cross
    mean_reversion
    volatility_target
    wyckoff_accumulation
  ].freeze
  CONFIGURATION_ATTRIBUTES = %w[
    asset_id interval strategy_key resolved_parameters from_time to_time
    fee_percentage slippage_percentage starting_capital
  ].freeze
  RESULT_METRICS = %i[
    final_equity total_return_percentage cagr_percentage
    maximum_drawdown_percentage sharpe_ratio exposure_percentage
    win_rate_percentage benchmark_cagr_percentage
    benchmark_maximum_drawdown_percentage
  ].freeze
  enum :status, { queued: 0, running: 1, completed: 2, failed: 3 }, validate: true
  enum :interval, { one_hour: 0, one_day: 1 }, validate: true

  belongs_to :user
  belongs_to :asset
  has_many :backtest_trades, dependent: :destroy

  validates :strategy_key, inclusion: { in: STRATEGY_KEYS }
  validates :from_time, :to_time, presence: true
  validates :starting_capital, numericality: { greater_than: 0 }
  validates :fee_percentage, :slippage_percentage,
    numericality: { greater_than_or_equal_to: 0 }
  validates :bar_count, :trade_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :final_equity,
    numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_return_percentage, :cagr_percentage, :benchmark_cagr_percentage,
    numericality: { greater_than_or_equal_to: -100 }, allow_nil: true
  validates :maximum_drawdown_percentage, :benchmark_maximum_drawdown_percentage,
    numericality: { greater_than_or_equal_to: -100, less_than_or_equal_to: 0 }, allow_nil: true
  validates :exposure_percentage, :win_rate_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :sharpe_ratio, numericality: true, allow_nil: true
  validates_each(*RESULT_METRICS, allow_nil: true) do |record, attribute, value|
    record.errors.add(attribute, :not_a_number) unless value.finite?
  end
  validates :label, length: { maximum: 100 }, allow_blank: true
  validates :error_message, length: { maximum: 1_000 }, allow_blank: true
  validate :time_range_is_valid
  validate :combined_cost_is_below_one_hundred_percent
  validate :resolved_parameters_is_an_object
  validate :equity_curve_is_an_array
  validate :configuration_is_immutable_after_execution_starts, on: :update

  scope :recent, -> { order(created_at: :desc) }
  scope :for_strategy, ->(strategy_key) { where(strategy_key:) }
  scope :for_asset, ->(asset) { where(asset:) }

  before_validation :resolve_strategy_parameters, on: :create

  def display_name
    label.presence || "#{asset.symbol} #{strategy_key.humanize}"
  end

  private
    def resolve_strategy_parameters
      return unless strategy_key.present? && STRATEGY_KEYS.include?(strategy_key)

      self.resolved_parameters = Backtest::Strategies.resolve(strategy_key, resolved_parameters || {})
    rescue Backtest::InvalidStrategyParameters => error
      errors.add(:resolved_parameters, error.message)
    end
    def time_range_is_valid
      return if from_time.blank? || to_time.blank? || from_time <= to_time

      errors.add(:to_time, "must be on or after the start time")
    end

    def combined_cost_is_below_one_hundred_percent
      return if fee_percentage.blank? || slippage_percentage.blank?
      return if fee_percentage + slippage_percentage < 100

      errors.add(:base, "combined fee and slippage must be below 100% per fill")
    end

    def resolved_parameters_is_an_object
      errors.add(:resolved_parameters, "must be an object") unless resolved_parameters.is_a?(Hash)
    end

    def equity_curve_is_an_array
      errors.add(:equity_curve, "must be an array") unless equity_curve.is_a?(Array)
    end

    def configuration_is_immutable_after_execution_starts
      return if attribute_in_database("status") == "queued"

      changed = CONFIGURATION_ATTRIBUTES.select { |attribute| will_save_change_to_attribute?(attribute) }
      return if changed.empty?

      errors.add(:base, "configuration cannot change after execution starts: #{changed.join(', ')}")
    end
end
