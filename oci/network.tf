resource "oci_core_vcn" "game_vcn" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "game-vcn"
}

resource "oci_core_internet_gateway" "ig" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ig.id
  }
}

locals {
  # This security list is the real perimeter: Docker-published ports bypass the host's INPUT chain.
  ingress_rules = concat(
    [
      { desc = "HTTP (ACME + redirect)", proto = "TCP", source = "0.0.0.0/0", min = 80, max = 80 },
      { desc = "HTTPS (panel)", proto = "TCP", source = "0.0.0.0/0", min = 443, max = 443 },
      { desc = "Wings SFTP", proto = "TCP", source = "0.0.0.0/0", min = 2022, max = 2022 },
      { desc = "Game servers", proto = "TCP", source = "0.0.0.0/0", min = var.game_port_range.min, max = var.game_port_range.max },
      { desc = "Game servers", proto = "UDP", source = "0.0.0.0/0", min = var.game_port_range.min, max = var.game_port_range.max },
      # SSH is not public: normal access is over Tailscale, break-glass is OCI Bastion (inside the VCN).
      { desc = "SSH from VCN (OCI Bastion)", proto = "TCP", source = var.vcn_cidr, min = 22, max = 22 },
    ],
    [for cidr in var.ssh_bootstrap_cidrs :
      { desc = "SSH bootstrap", proto = "TCP", source = cidr, min = 22, max = 22 }
    ],
    # Lets tailnet devices connect directly instead of through relays. WireGuard ignores
    # anything that isn't from a known device.
    [{ desc = "Tailscale direct", proto = "UDP", source = "0.0.0.0/0", min = 41641, max = 41641 }],
  )
}

resource "oci_core_security_list" "sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {
    for_each = local.ingress_rules
    content {
      description = ingress_security_rules.value.desc
      protocol    = ingress_security_rules.value.proto == "TCP" ? "6" : "17"
      source      = ingress_security_rules.value.source

      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.proto == "TCP" ? [1] : []
        content {
          min = ingress_security_rules.value.min
          max = ingress_security_rules.value.max
        }
      }

      dynamic "udp_options" {
        for_each = ingress_security_rules.value.proto == "UDP" ? [1] : []
        content {
          min = ingress_security_rules.value.min
          max = ingress_security_rules.value.max
        }
      }
    }
  }

  # Path MTU discovery ("fragmentation needed"); OCI's default list includes these too.
  ingress_security_rules {
    description = "ICMP fragmentation needed"
    protocol    = "1"
    source      = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "ICMP unreachable within VCN"
    protocol    = "1"
    source      = var.vcn_cidr
    icmp_options {
      type = 3
    }
  }
}

resource "oci_core_subnet" "subnet" {
  cidr_block        = cidrsubnet(var.vcn_cidr, 8, 1)
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.game_vcn.id
  route_table_id    = oci_core_route_table.rt.id
  security_list_ids = [oci_core_security_list.sec_list.id]
}
