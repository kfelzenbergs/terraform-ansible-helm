terraform {
  required_providers {
    virtualbox = {
      source = "shekeriev/virtualbox"
      version = "0.0.4"
    }
  }
}

provider "virtualbox" {
  delay      = 10
  mintimeout = 5
}

resource "virtualbox_vm" "node" {
  count     = 1
  name      = format("${var.node_name}-%02d", count.index + 1)
  image     = "https://app.vagrantup.com/generic/boxes/debian11/versions/4.2.14/providers/virtualbox.box"
  cpus      = 2
  memory    = "3048 mib"
  user_data = file("${path.module}/user_data")

  network_adapter {
    type           = "bridged"
    device         = "IntelPro1000MTDesktop"
    host_interface = var.host_interface
  }
}

output "IPAddress" {
  value = element(virtualbox_vm.node.*.network_adapter.0.ipv4_address, 1)
}
