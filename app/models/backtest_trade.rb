class BacktestTrade < ApplicationRecord
  belongs_to :backtest_run

  validates :entry_time, presence: true
  validates :entry_price, numericality: { greater_than: 0 }
  validates :exit_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :return_percentage, numericality: true, allow_nil: true
  validates :holding_bars, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :exit_time_follows_entry
  validate :closed_trade_has_exit_values

  scope :chronological, -> { order(:entry_time) }

  private
    def exit_time_follows_entry
      return if exit_time.blank? || entry_time.blank? || exit_time >= entry_time

      errors.add(:exit_time, "must be on or after entry time")
    end

    def closed_trade_has_exit_values
      return if open_position? || (exit_time.present? && exit_price.present? && return_percentage.present?)

      errors.add(:base, "closed trades require exit time, exit price, and return")
    end
end
