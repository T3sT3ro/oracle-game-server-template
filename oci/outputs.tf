output "public_ip" {
  value       = oci_core_instance.server.public_ip
  description = "Public IP of the instance (point the panel/SFTP DNS records here)"
}

output "instance_id" {
  value       = oci_core_instance.server.id
  description = "Instance OCID (OCI Bastion sessions, reimaging)"
}

output "private_ip" {
  value       = oci_core_instance.server.private_ip
  description = "Private IP inside the VCN (target for OCI Bastion managed SSH sessions)"
}

output "data_device" {
  value       = oci_core_volume_attachment.block_attachment.device
  description = "Consistent device path of the data volume"
}
