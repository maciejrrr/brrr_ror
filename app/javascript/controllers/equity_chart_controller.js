import { Controller } from "@hotwired/stimulus"
import { createChart, AreaSeries } from "lightweight-charts"

export default class extends Controller {
  static values = {
    curve: Array
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
    if (!this.curveValue || this.curveValue.length === 0) return

    const container = this.element
    container.innerHTML = ""

    this.chart = createChart(container, {
      width: container.clientWidth || 800,
      height: 380,
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

    const areaSeries = this.chart.addSeries(AreaSeries, {
      topColor: "rgba(16, 185, 129, 0.35)",
      bottomColor: "rgba(16, 185, 129, 0.0)",
      lineColor: "#10b981",
      lineWidth: 2,
    })

    const data = this.curveValue.map(point => ({
      time: typeof point.time === "number" ? point.time : Math.floor(new Date(point.time).getTime() / 1000),
      value: Number(point.value)
    }))

    areaSeries.setData(data)
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
