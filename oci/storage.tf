resource "oci_core_volume" "data_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  size_in_gbs         = 150
}

resource "oci_core_volume_attachment" "block_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.server.id
  volume_id       = oci_core_volume.data_volume.id
}
