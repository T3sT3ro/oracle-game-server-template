provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# --- Networking ---
resource "oci_core_vcn" "game_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "game-server-vcn"
}

resource "oci_core_internet_gateway" "ig" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id
  display_name   = "game-internet-gateway"
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id
  display_name   = "game-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ig.id
  }
}

resource "oci_core_security_list" "game_sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.game_vcn.id
  display_name   = "game-security-list"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Ingress Rules: SSH(22), HTTP(80), HTTPS(443), Pelican SFTP(2022), Wings(8080), MC(25565)
  dynamic "ingress_security_rules" {
    for_each = [
      { port = 22, proto = "6" },
      { port = 80, proto = "6" },
      { port = 443, proto = "6" },
      { port = 2022, proto = "6" },
      { port = 8080, proto = "6" },
      { port = 25565, proto = "6" },
      { port = 25565, proto = "17" }
    ]
    content {
      protocol = ingress_security_rules.value.proto
      source   = "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value.proto == "6" ? ingress_security_rules.value.port : null
        max = ingress_security_rules.value.proto == "6" ? ingress_security_rules.value.port : null
      }
      udp_options {
        min = ingress_security_rules.value.proto == "17" ? ingress_security_rules.value.port : null
        max = ingress_security_rules.value.proto == "17" ? ingress_security_rules.value.port : null
      }
    }
  }
}

resource "oci_core_subnet" "game_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.game_vcn.id
  route_table_id    = oci_core_route_table.rt.id
  security_list_ids = [oci_core_security_list.game_sec_list.id]
  display_name      = "game-public-subnet"
}

# --- Static Public IP ---
resource "oci_core_public_ip" "reserved_ip" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "game-server-static-ip"
}

# --- Compute Instance (PAYG Limits: 2 OCPU, 12 GB RAM) ---
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
}

resource "oci_core_instance" "game_server" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.A1.Flex"
  display_name        = "game-server-node"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.game_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# --- Persistent Block Storage ---
resource "oci_core_volume" "data_volume" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "game-data-volume"
  size_in_gbs         = 100
}

resource "oci_core_volume_attachment" "va" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.game_server.id
  volume_id       = oci_core_volume.data_volume.id
}

output "public_ip" {
  value = oci_core_instance.game_server.public_ip
}