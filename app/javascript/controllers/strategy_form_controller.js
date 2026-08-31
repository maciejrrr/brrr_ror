import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["strategySelect", "paramGroup", "assetSelect", "fromTime", "toTime"]

  connect() {
    this.updateVisibleParams()
    this.updateDateBounds()
  }

  strategyChanged() {
    this.updateVisibleParams()
  }

  assetChanged() {
    this.updateDateBounds()
  }

  fromTimeChanged() {
    if (this.hasFromTimeTarget && this.hasToTimeTarget && this.fromTimeTarget.value) {
      this.toTimeTarget.min = this.fromTimeTarget.value
    }
  }

  toTimeChanged() {
    if (this.hasFromTimeTarget && this.hasToTimeTarget && this.toTimeTarget.value) {
      const assetMax = this.assetSelectTarget?.selectedOptions[0]?.dataset.maxDate || this.toTimeTarget.value
      this.fromTimeTarget.max = this.toTimeTarget.value < assetMax ? this.toTimeTarget.value : assetMax
    }
  }

  updateVisibleParams() {
    if (!this.hasStrategySelectTarget) return

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

  updateDateBounds() {
    if (!this.hasAssetSelectTarget || !this.hasFromTimeTarget || !this.hasToTimeTarget) return

    const selectedOption = this.assetSelectTarget.selectedOptions[0]
    if (!selectedOption) return

    const minDate = selectedOption.dataset.minDate
    const maxDate = selectedOption.dataset.maxDate

    if (minDate) {
      this.fromTimeTarget.min = minDate
      this.toTimeTarget.min = minDate
    }
    if (maxDate) {
      this.fromTimeTarget.max = maxDate
      this.toTimeTarget.max = maxDate
    }

    if (minDate && this.fromTimeTarget.value && this.fromTimeTarget.value < minDate) {
      this.fromTimeTarget.value = minDate
    }
    if (maxDate && this.toTimeTarget.value && this.toTimeTarget.value > maxDate) {
      this.toTimeTarget.value = maxDate
    }
  }
}
