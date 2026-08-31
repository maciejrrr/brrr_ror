module ApplicationHelper
  def format_currency(value)
    return "—" if value.nil?

    number_to_currency(value, precision: 2)
  end

  def format_percentage(value, precision: 2)
    return "—" if value.nil?

    prefix = value.positive? ? "+" : ""
    "#{prefix}#{number_to_percentage(value, precision: precision)}"
  end

  def format_ratio(value, precision: 2)
    return "—" if value.nil?

    sprintf("%.#{precision}f", value)
  end

  def format_utc(time, format: :short)
    return "—" if time.blank?

    utc_time = time.utc
    case format
    when :short
      utc_time.strftime("%Y-%m-%d %H:%M UTC")
    when :date
      utc_time.strftime("%Y-%m-%d")
    when :time
      utc_time.strftime("%H:%M UTC")
    else
      utc_time.strftime("%Y-%m-%d %H:%M:%S UTC")
    end
  end

  def status_badge_class(status)
    case status.to_s
    when "completed"
      "bg-emerald-950/80 text-emerald-400 border-emerald-800/60"
    when "running"
      "bg-blue-950/80 text-blue-400 border-blue-800/60 animate-pulse"
    when "queued"
      "bg-amber-950/80 text-amber-400 border-amber-800/60"
    when "failed"
      "bg-rose-950/80 text-rose-400 border-rose-800/60"
    else
      "bg-zinc-800 text-zinc-400 border-zinc-700"
    end
  end

  def return_color_class(value)
    return "text-zinc-400" if value.nil? || value.zero?

    value.positive? ? "text-emerald-400" : "text-rose-400"
  end
end
