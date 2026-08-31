require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "format_currency handles values and nil" do
    assert_equal "$1,234.56", format_currency(1234.56)
    assert_equal "—", format_currency(nil)
  end

  test "format_percentage handles positive, negative, zero and nil" do
    assert_equal "+12.34%", format_percentage(12.34)
    assert_equal "-5.00%", format_percentage(-5.0)
    assert_equal "0.00%", format_percentage(0.0)
    assert_equal "—", format_percentage(nil)
  end

  test "format_ratio formats float precision" do
    assert_equal "1.45", format_ratio(1.4523, precision: 2)
    assert_equal "—", format_ratio(nil)
  end

  test "format_utc supports formats and nil" do
    time = Time.utc(2024, 5, 10, 14, 30, 45)
    assert_equal "2024-05-10 14:30 UTC", format_utc(time, format: :short)
    assert_equal "2024-05-10", format_utc(time, format: :date)
    assert_equal "14:30 UTC", format_utc(time, format: :time)
    assert_equal "2024-05-10 14:30:45 UTC", format_utc(time, format: :full)
    assert_equal "—", format_utc(nil)
    assert_equal "—", format_utc("")
  end

  test "status_badge_class returns appropriate classes" do
    assert_includes status_badge_class("completed"), "text-emerald-400"
    assert_includes status_badge_class("running"), "text-blue-400"
    assert_includes status_badge_class("queued"), "text-amber-400"
    assert_includes status_badge_class("failed"), "text-rose-400"
    assert_includes status_badge_class("unknown"), "text-zinc-400"
  end

  test "return_color_class returns appropriate text colors" do
    assert_equal "text-emerald-400", return_color_class(10.5)
    assert_equal "text-rose-400", return_color_class(-3.2)
    assert_equal "text-zinc-400", return_color_class(0)
    assert_equal "text-zinc-400", return_color_class(nil)
  end
end
