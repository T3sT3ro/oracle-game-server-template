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
  type        = string
  description = "Receives budget alerts and monitoring alarms. Confirm the OCI subscription email after the first apply."
}

variable "mail_from_address" {
  type        = string
  default     = ""
  description = "Sender address for the panel's mail via OCI Email Delivery, e.g. admin@example.com. Empty = no mail setup (see email.tf)."

  validation {
    condition     = var.mail_from_address == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.mail_from_address))
    error_message = "mail_from_address must be empty or an email address."
  }
}

variable "instance_name" {
  type    = string
  default = "calagopus"
}

# A1 compute that stays free on a Pay As You Go account: 4 OCPU / 24 GB in total.
# (Oracle's docs list 2 OCPU / 12 GB for Always Free-only accounts since June 2026; PAYG
# accounts keep 4/24 per Oracle support. The free-tier-guard budget emails on any charge.)
# The validations stop Terraform from creating a bigger, billed instance by mistake.
variable "instance_ocpus" {
  type    = number
  default = 4

  validation {
    condition     = var.instance_ocpus >= 1 && var.instance_ocpus <= 4
    error_message = "More than 4 A1 OCPUs is not free."
  }
}

variable "instance_memory_gbs" {
  type    = number
  default = 24

  validation {
    condition     = var.instance_memory_gbs >= 1 && var.instance_memory_gbs <= 24
    error_message = "More than 24 GB of A1 memory is not free."
  }
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "game_port_range" {
  type = object({ min = number, max = number })
  default = {
    min = 25500
    max = 25600
  }
  description = "Public TCP+UDP range for game servers. Create Calagopus allocations from this range."

  validation {
    condition     = var.game_port_range.min >= 1024 && var.game_port_range.min <= var.game_port_range.max && var.game_port_range.max <= 65535
    error_message = "game_port_range must be 1024 <= min <= max <= 65535."
  }
}

variable "game_default_ports" {
  type        = list(object({ name = string, proto = string, port = number }))
  default     = []
  description = <<-EOT
    Extra public ports, so one server per game can use the game's default port and players can
    leave the port out (islands.factorio.example.com instead of ...:25510). Each needs a matching
    0.0.0.0 allocation in the panel. Example: [{ name = "Factorio", proto = "UDP", port = 34197 }]
  EOT

  validation {
    condition     = alltrue([for p in var.game_default_ports : contains(["TCP", "UDP"], p.proto) && p.port >= 1024 && p.port <= 65535])
    error_message = "game_default_ports: proto must be \"TCP\" or \"UDP\", and port between 1024 and 65535."
  }
}

variable "ssh_bootstrap_cidrs" {
  type        = list(string)
  default     = []
  description = "Extra CIDRs allowed to reach SSH from the internet. Only set during bootstrap (before Tailscale is up), e.g. [\"203.0.113.7/32\"]; leave empty afterwards."
}

variable "enable_volume_backups" {
  type        = bool
  default     = true
  description = "Weekly incremental backups of the data volume. Retention is kept low to stay within the Always Free backup count."
}
