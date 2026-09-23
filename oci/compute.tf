data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
}

resource "oci_core_instance" "server" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  preserve_boot_volume = true

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }


  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready!'"]

    # Waiting for SSH to become available
    connection {
      type    = "ssh"
      user    = "ubuntu"       # default user for ubuntu
      host    = self.public_ip # Pobiera IP z właśnie tworzonej maszyny
      timeout = "2m"
    }
  }

  # provisioner "local-exec" {
  #   command = "echo 'ansible-playbook -i '${self.public_ip},' -u ubuntu --ask-vault-pass ../ansible/playbook.yml"
  # }
}
