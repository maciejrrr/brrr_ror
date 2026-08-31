import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2000 },
    active: { type: Boolean, default: true }
  }

  connect() {
    if (this.activeValue) {
      this.timer = setInterval(() => {
        Turbo.visit(window.location.href, { action: "replace" })
      }, this.intervalValue)
    }
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }
}
