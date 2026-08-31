import { Controller } from "@hotwired/stimulus"
import { createChart, CandlestickSeries } from "lightweight-charts"

export default class extends Controller {
  static values = {
    candles: Array
  }

  connect() {
    this.renderChart()
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
    if (this.chart) {
      this.chart.remove()
      this.chart = null
    }
  }

  renderChart() {
    if (!this.candlesValue || this.candlesValue.length === 0) return

    const container = this.element
    container.innerHTML = ""

    this.chart = createChart(container, {
      width: container.clientWidth || 800,
      height: 480,
      layout: {
        background: { color: "#09090b" },
        textColor: "#a1a1aa",
      },
      grid: {
        vertLines: { color: "#18181b" },
        horzLines: { color: "#18181b" },
      },
      crosshair: {
        mode: 1,
      },
      rightPriceScale: {
        borderColor: "#27272a",
        scaleMargins: {
          top: 0.1,
          bottom: 0.1,
        },
      },
      timeScale: {
        borderColor: "#27272a",
        timeVisible: true,
        secondsVisible: false,
      },
    })

    const candlestickSeries = this.chart.addSeries(CandlestickSeries, {
      upColor: "#10b981",
      downColor: "#f43f5e",
      borderVisible: false,
      wickUpColor: "#10b981",
      wickDownColor: "#f43f5e",
    })

    const formattedData = this.candlesValue.map(c => ({
      time: typeof c.time === "number" ? c.time : Math.floor(new Date(c.time).getTime() / 1000),
      open: Number(c.open),
      high: Number(c.high),
      low: Number(c.low),
      close: Number(c.close),
    }))

    candlestickSeries.setData(formattedData)
    this.chart.timeScale().fitContent()

    this.resizeObserver = new ResizeObserver(entries => {
      if (!entries || entries.length === 0) return
      const entry = entries[0]
      if (this.chart && entry.contentRect.width > 0) {
        this.chart.applyOptions({ width: entry.contentRect.width })
      }
    })
    this.resizeObserver.observe(container)
  }
}
