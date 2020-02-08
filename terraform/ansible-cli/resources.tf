
provider "libvirt" {
  alias = "dell"
  uri = "qemu:///system"
}

resource "libvirt_volume" "ansible" {

  count = 2
  name = "ansible-cli${count.index +1}.qcow2"
  pool = "default"
  source = "/var/lib/libvirt/images/CentOS-7.x86_64-kvm-and-xen.qcow2"
  format = "qcow2"
}

resource "libvirt_domain" "ansible" {

  count  = 2
  name   = "ansible-cli${count.index +1}"
  memory = "1024"
  vcpu   = 2

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = element(libvirt_volume.ansible.*.id, count.index)
  }

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }

}

terraform {
  required_version = ">= 0.12"
}


