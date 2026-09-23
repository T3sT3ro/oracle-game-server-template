resource "oci_core_vcn" "game_vcn" {
  cidr_block     = "10.0.0.0/16"
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

resource "oci_core_security_list" "sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all" # "all" is correct for egress
  }

  # Ingress Rules: SSH(22), HTTP(80), HTTPS(443), Calagopus SFTP(2022), Wings(8080), MC(25565)
  dynamic "ingress_security_rules" {
    for_each = [
      { port = 22, proto = "TCP" },
      { port = 80, proto = "TCP" },
      { port = 443, proto = "TCP" },
      { port = 2022, proto = "TCP" },
      { port = 8080, proto = "TCP" },
      { port = 25565, proto = "TCP" },
      { port = 25565, proto = "UDP" }
    ]
    content {
      protocol = ingress_security_rules.value.proto == "TCP" ? "6" : "17"
      source   = "0.0.0.0/0"

      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.proto == "TCP" ? [1] : []
        content {
          min = ingress_security_rules.value.port
          max = ingress_security_rules.value.port
        }
      }

      dynamic "udp_options" {
        for_each = ingress_security_rules.value.proto == "UDP" ? [1] : []
        content {
          min = ingress_security_rules.value.port
          max = ingress_security_rules.value.port
        }
      }
    }
  }
}


resource "oci_core_subnet" "subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.game_vcn.id
  route_table_id    = oci_core_route_table.rt.id
  security_list_ids = [oci_core_security_list.sec_list.id]
}
