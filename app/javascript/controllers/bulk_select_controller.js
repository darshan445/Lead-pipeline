import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["master", "item"]

  toggleAll() {
    const checked = this.masterTarget.checked
    this.itemTargets.forEach((item) => {
      item.checked = checked
    })
  }

  syncMaster() {
    if (this.itemTargets.length === 0) {
      this.masterTarget.checked = false
      this.masterTarget.indeterminate = false
      return
    }

    const checkedCount = this.itemTargets.filter((item) => item.checked).length
    this.masterTarget.checked = checkedCount === this.itemTargets.length
    this.masterTarget.indeterminate = checkedCount > 0 && checkedCount < this.itemTargets.length
  }
}
