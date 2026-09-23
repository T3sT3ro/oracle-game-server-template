
output "public_ip" {
  value       = oci_core_instance.server.public_ip
  description = "Public IP of the instance"
}
