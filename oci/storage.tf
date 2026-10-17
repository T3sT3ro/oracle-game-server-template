resource "oci_core_volume" "data_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance_name}-data"
  size_in_gbs         = 150
}

resource "oci_core_volume_attachment" "block_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.server.id
  volume_id       = oci_core_volume.data_volume.id
  # Consistent device path: Ansible formats and mounts this, never a guessed /dev/sdX.
  device = "/dev/oracleoci/oraclevdb"
}

# Weekly incremental backups with short retention: at most ~4 backups exist at once.
# The Always Free allowance is 5 volume backups in total, boot AND block volumes combined,
# so manual boot-volume backups must stay at 1 (or be deleted) to keep this free.
resource "oci_core_volume_backup_policy" "weekly" {
  count          = var.enable_volume_backups ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.instance_name}-data-weekly"

  schedules {
    backup_type       = "INCREMENTAL"
    period            = "ONE_WEEK"
    day_of_week       = "MONDAY"
    hour_of_day       = 4
    time_zone         = "UTC"
    retention_seconds = 3 * 7 * 24 * 3600
  }
}

resource "oci_core_volume_backup_policy_assignment" "data_weekly" {
  count     = var.enable_volume_backups ? 1 : 0
  asset_id  = oci_core_volume.data_volume.id
  policy_id = oci_core_volume_backup_policy.weekly[0].id
}
