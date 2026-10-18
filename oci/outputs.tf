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

# ---- Panel mail (only when mail_from_address is set) ----

output "mail_smtp" {
  value = local.mail_enabled ? {
    host     = "smtp.email.${var.region}.oci.oraclecloud.com"
    port     = 465
    tls      = "Implicit TLS"
    username = oci_identity_smtp_credential.mail[0].username
    from     = var.mail_from_address
  } : null
  description = "SMTP settings for the panel (Admin -> Settings -> Mail). Password: mail_smtp_password."
}

output "mail_smtp_password" {
  value       = local.mail_enabled ? oci_identity_smtp_credential.mail[0].password : null
  sensitive   = true
  description = "Read with: terraform -chdir=oci output -raw mail_smtp_password"
}

output "mail_dns_records" {
  value = local.mail_enabled ? {
    dkim_cname = {
      name  = oci_email_dkim.mail[0].dns_subdomain_name
      value = oci_email_dkim.mail[0].cname_record_value
    }
    spf_txt = "Add include:${local.mail_spf_include} to your one SPF record, e.g. v=spf1 include:_spf.porkbun.com include:${local.mail_spf_include} ~all"
  } : null
  description = "DNS records to add at your DNS provider for panel mail."
}
