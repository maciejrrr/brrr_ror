class PriceBar < ApplicationRecord
  INTERVAL_SECONDS = { "one_hour" => 1.hour.to_i, "one_day" => 1.day.to_i }.freeze

  enum :interval, { one_hour: 0, one_day: 1 }, validate: true
  enum :data_source, { demo: 0, provider: 1 }, validate: true

  belongs_to :asset

  validates :open_time, presence: true, uniqueness: { scope: %i[ asset_id interval ] }
  validates :open, :high, :low, :close, numericality: { greater_than: 0 }
  validates :volume, numericality: { greater_than_or_equal_to: 0 }
  validate :ohlc_values_are_coherent
  validate :open_time_is_aligned

  scope :chronological, -> { order(:open_time) }
  scope :for_interval, ->(interval) { where(interval:) }
  scope :between, ->(from_time, to_time) { where(open_time: from_time..to_time) }
  scope :latest_first, -> { order(open_time: :desc) }

  private
    def ohlc_values_are_coherent
      return unless [ open, high, low, close ].all?
      return if low <= open && low <= close && high >= open && high >= close && high >= low

      errors.add(:base, "OHLC values are not coherent")
    end

    def open_time_is_aligned
      return if open_time.blank? || interval.blank?
      interval_seconds = INTERVAL_SECONDS.fetch(interval)
      return if open_time.usec.zero? && (open_time.to_i % interval_seconds).zero?

      errors.add(:open_time, "must align to the candle interval in UTC")
    end
end
