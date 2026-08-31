import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["strategySelect", "paramGroup"]

  connect() {
    this.updateVisibleParams()
  }

  strategyChanged() {
    this.updateVisibleParams()
  }

  updateVisibleParams() {
    const selectedKey = this.strategySelectTarget.value
    this.paramGroupTargets.forEach(group => {
      if (group.dataset.strategyKey === selectedKey) {
        group.classList.remove("hidden")
        group.querySelectorAll("input, select").forEach(el => el.removeAttribute("disabled"))
      } else {
        group.classList.add("hidden")
        group.querySelectorAll("input, select").forEach(el => el.setAttribute("disabled", "disabled"))
      }
    })
  }
}
