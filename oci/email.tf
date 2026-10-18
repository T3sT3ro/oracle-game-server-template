# Outgoing mail for the panel (invites, password resets) through OCI Email Delivery.
# Off until mail_from_address is set. Always Free covers 3,000 emails a month; the panel sends
# a handful. After apply, add the DNS records from `terraform output mail_dns_records` and
# put the SMTP login into the panel (README, "Email from the panel").

locals {
  mail_enabled = var.mail_from_address != ""
  mail_domain  = local.mail_enabled ? split("@", var.mail_from_address)[1] : ""
  # Oracle's SPF include depends on the region's continent.
  mail_spf_include = (
    startswith(var.region, "eu-") || startswith(var.region, "uk-") || startswith(var.region, "me-") || startswith(var.region, "af-") || startswith(var.region, "il-")
    ? "eu.rp.oracleemaildelivery.com"
    : startswith(var.region, "ap-") ? "ap.rp.oracleemaildelivery.com" : "rp.oracleemaildelivery.com"
  )
}

resource "oci_email_email_domain" "mail" {
  count          = local.mail_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = local.mail_domain
  description    = "Panel mail"
}

# DKIM signs outgoing mail. Its CNAME record has to be added at your DNS provider.
resource "oci_email_dkim" "mail" {
  count           = local.mail_enabled ? 1 : 0
  email_domain_id = oci_email_email_domain.mail[0].id
  description     = "Panel mail"
}

resource "oci_email_sender" "mail" {
  count          = local.mail_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  email_address  = var.mail_from_address
  depends_on     = [oci_email_email_domain.mail]
}

# SMTP login for your API user (each user can have 2). Oracle shows the password only once,
# so Terraform's state keeps the only copy: `terraform -chdir=oci output -raw mail_smtp_password`.
resource "oci_identity_smtp_credential" "mail" {
  count       = local.mail_enabled ? 1 : 0
  user_id     = var.user_ocid
  description = "Calagopus panel mail"
}
