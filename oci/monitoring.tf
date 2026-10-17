# Out-of-band alerting: these alarms are evaluated by OCI, so they still fire when the
# instance (and everything monitoring it from the inside) is down. Disk fill level is not
# exposed by the OCI agent; Beszel alerts on that from inside the host.
#
# No CPU alarm: game servers can run at high CPU for hours and that's normal.
# Free-tier budget: 2 alarms re-notifying every 4 h is at most ~360 emails/month even if both
# fire for a whole month (free: 1,000 emails/month). Keep that in mind when adding alarms.

resource "oci_ons_notification_topic" "alerts" {
  compartment_id = var.compartment_ocid
  name           = "${var.instance_name}-alerts"
  description    = "Monitoring alarms for ${var.instance_name}"
}

# OCI sends a confirmation email; alarms are not delivered until it is confirmed.
resource "oci_ons_subscription" "alerts_email" {
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.alerts.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}

locals {
  instance_filter = "{resourceId = \"${oci_core_instance.server.id}\"}"

  alarms = {
    instance_down = {
      severity = "CRITICAL"
      query    = "CpuUtilization[1m]${local.instance_filter}.absent()"
      pending  = "PT5M"
      body     = "No metrics from ${var.instance_name} for 5 minutes: the instance, its network, or the OCI agent is down."
    }
    memory_high = {
      severity = "WARNING"
      query    = "MemoryUtilization[5m]${local.instance_filter}.mean() > 90"
      pending  = "PT15M"
      body     = "Memory on ${var.instance_name} has been above 90% for 15 minutes."
    }
  }
}

resource "oci_monitoring_alarm" "instance" {
  for_each = local.alarms

  compartment_id        = var.compartment_ocid
  metric_compartment_id = var.compartment_ocid
  display_name          = "${var.instance_name}-${replace(each.key, "_", "-")}"
  namespace             = "oci_computeagent"
  query                 = each.value.query
  severity              = each.value.severity
  pending_duration      = each.value.pending
  body                  = each.value.body
  message_format        = "ONS_OPTIMIZED"
  is_enabled            = true
  destinations          = [oci_ons_notification_topic.alerts.id]

  repeat_notification_duration = "PT4H"
}
