resource "scaleway_instance_ip" "test_ip" {
  for_each = local.regions
  type     = "routed_ipv4"
  zone     = format("%s-1", each.key)
}

resource "scaleway_instance_security_group" "ssh" {
  for_each                = local.regions
  zone                    = format("%s-1", each.key)
  name                    = format("ssh-%s-1", each.key)
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = "22"
  }
}

resource "scaleway_instance_server" "test_srv" {
  for_each          = local.regions
  zone              = format("%s-1", each.key)
  name              = format("test-%s", each.key)
  image             = "ubuntu_jammy"
  type              = "PLAY2-PICO"
  security_group_id = scaleway_instance_security_group.ssh[each.key].id
  ip_id             = scaleway_instance_ip.test_ip[each.key].id

  private_network {
    pn_id = scaleway_vpc_private_network.pn[each.key].id
  }

  root_volume {
    delete_on_termination = true
  }

  user_data = {
    cloud-init = <<-EOT
    #cloud-config
    package_update: true
    packages:
    - postgresql-client
    write_files:
    - path: /etc/netplan/99-overrides.yaml
      permissions: '0644'
      content: |
        network:
          version: 2
          ethernets:
            ens2:
              dhcp4-overrides:
                route-metric: 10
    EOT
  }
}

output "test_servers" {
  value = [for instance in scaleway_instance_server.test_srv : "${instance.name}: ssh root@${instance.public_ip}"]
}
