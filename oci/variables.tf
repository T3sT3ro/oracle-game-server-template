variable "user_ocid" { type = string }
variable "fingerprint" { type = string }
variable "tenancy_ocid" { type = string }
variable "region" { type = string }
variable "private_key_path" {
  type    = string
  default = "./api_key.pem"
}

variable "private_key_pass" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "compartment_ocid" { type = string }

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "notification_email" {
  type = string
}
