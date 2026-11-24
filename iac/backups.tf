# Scheduled backups of the shared observability volume (Prometheus, Loki and
# Grafana data). The volume itself is created by the OKE CSI driver, not by
# Terraform, so it is referenced by OCID.
#
# The backup-count quota (cost-guardrails.tf) is 5, so retention is capped at 4
# days: at most 4 backups exist, plus 1 briefly while the oldest expires. A
# backup that would push the count past the quota fails instead of costing money.
#
# Backups are crash-consistent (like pulling the plug). Prometheus, Loki and
# Grafana's SQLite all recover from that through their write-ahead logs.

variable "observability_volume_id" {
  type        = string
  description = <<-EOT
    OCID of the block volume behind the observability PVC. It changes whenever
    the PVC is recreated. Find it with:
      kubectl get pv $(kubectl get pvc -n observability observability-data-prometheus-prometheus-kube-prometheus-prometheus-0 -o jsonpath='{.spec.volumeName}') -o jsonpath='{.spec.csi.volumeHandle}'
  EOT
}

variable "backup_hour_utc" {
  type        = number
  description = "Hour of day (UTC) the daily backup starts"
  default     = 8 # 3-4 AM US Eastern
}

variable "backup_retention_days" {
  type        = number
  description = "How many days each daily backup is kept"
  default     = 4

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 4
    error_message = "Keep retention at 1-4 days so backups stay under the backup-count quota of 5."
  }
}

resource "oci_core_volume_backup_policy" "observability" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-observability-daily"

  schedules {
    backup_type       = "INCREMENTAL"
    period            = "ONE_DAY"
    hour_of_day       = var.backup_hour_utc
    offset_type       = "STRUCTURED"
    time_zone         = "UTC"
    retention_seconds = var.backup_retention_days * 86400
  }
}

resource "oci_core_volume_backup_policy_assignment" "observability" {
  asset_id  = var.observability_volume_id
  policy_id = oci_core_volume_backup_policy.observability.id
}
