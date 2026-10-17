data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
}

resource "oci_core_instance" "server" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  preserve_boot_volume = true

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  agent_config {
    is_monitoring_disabled = false
    plugins_config {
      name          = "Compute Instance Monitoring" # metrics for the alarms in monitoring.tf
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Bastion" # break-glass SSH when Tailscale is down
      desired_state = "ENABLED"
    }
  }

  lifecycle {
    # The image data source always resolves to the newest build. Without this, every new
    # Canonical image would replace the instance (and orphan a preserved 50 GB boot volume,
    # which breaks the 200 GB Always Free storage limit). OS updates come from apt instead.
    # ssh_authorized_keys only seeds the first boot; OCI can't change it on a live instance.
    ignore_changes = [source_details[0].source_id, metadata]
  }
}
