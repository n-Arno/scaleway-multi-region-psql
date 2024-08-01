variable "app_token" {
  type = string
}

variable "yawm_url" {
  type = string
}

locals {
  regions = toset(["fr-par", "nl-ams"])
  zones   = toset(["fr-par-1", "fr-par-2", "nl-ams-1", "nl-ams-2"])
}

resource "random_uuid" "mesh" {}

resource "scaleway_vpc" "vpc" {
  for_each       = local.regions
  region         = each.key
  name           = "demo"
  enable_routing = true
}

resource "scaleway_vpc_private_network" "pn" {
  for_each = local.regions
  region   = each.key
  name     = "demo"
  vpc_id   = scaleway_vpc.vpc[each.key].id
}

resource "scaleway_instance_ip" "ip" {
  for_each = local.zones
  type     = "routed_ipv4"
  zone     = each.key
}

resource "scaleway_instance_security_group" "vpn" {
  for_each                = local.zones
  zone                    = each.key
  name                    = format("vpn-%s", join("-", slice(split("-", each.key), 1, 3)))
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = "22"
  }

  inbound_rule {
    action   = "accept"
    protocol = "UDP"
    port     = "52435"
  }
}

resource "scaleway_instance_volume" "data" {
  for_each   = local.zones
  zone       = each.key
  type       = "b_ssd"
  name       = format("vol-%s", join("-", slice(split("-", each.key), 1, 3)))
  size_in_gb = 20
}

resource "scaleway_instance_server" "srv" {
  for_each          = local.zones
  zone              = each.key
  name              = join("-", slice(split("-", each.key), 1, 3))
  image             = "ubuntu_jammy"
  type              = "PLAY2-PICO"
  security_group_id = scaleway_instance_security_group.vpn[each.key].id
  ip_id             = scaleway_instance_ip.ip[each.key].id

  private_network {
    pn_id = scaleway_vpc_private_network.pn[join("-", slice(split("-", each.key), 0, 2))].id
  }

  root_volume {
    delete_on_termination = true
  }

  additional_volume_ids = [scaleway_instance_volume.data[each.key].id]

  user_data = {
    cloud-init = <<-EOT
    #cloud-config
    runcmd:
    - apt-get update
    - apt-get install wireguard -y
    - "curl -X POST -H \"X-Auth-Token: ${var.app_token}\" ${var.yawm_url}/${random_uuid.mesh.result}"
    - sleep 1m
    - "curl -X GET -H \"X-Auth-Token: ${var.app_token}\" ${var.yawm_url}/${random_uuid.mesh.result} > /etc/wireguard/wg0.conf"
    - systemctl enable --now wg-quick@wg0
    - "echo 'type=83' | sfdisk /dev/sdb"
    - mkfs.ext4 /dev/sdb1
    - mkdir -p /mnt/data
    - "echo '/dev/sdb1 /mnt/data ext4 defaults 0 1' >> /etc/fstab"
    - mount -a
    EOT
  }
}

data "scaleway_ipam_ip" "pn_ip" {
  for_each    = local.zones
  region      = join("-", slice(split("-", each.key), 0, 2))
  mac_address = scaleway_instance_server.srv[each.key].private_network.0.mac_address
  type        = "ipv4"
}

resource "scaleway_ipam_ip" "vip" {
  for_each = local.regions
  region   = each.key
  source {
    private_network_id = scaleway_vpc_private_network.pn[each.key].id
  }
}

resource "scaleway_lb" "lb" {
  for_each           = local.regions
  zone               = format("%s-1", each.key)
  name               = format("lb-%s", each.key)
  type               = "LB-S"
  assign_flexible_ip = false
  private_network {
    private_network_id = scaleway_vpc_private_network.pn[each.key].id
    ipam_ids           = [scaleway_ipam_ip.vip[each.key].id]
  }
}

resource "scaleway_lb_backend" "sql" {
  for_each         = local.regions
  lb_id            = scaleway_lb.lb[each.key].id
  name             = "back-sql"
  forward_protocol = "tcp"
  forward_port     = "5432"
  server_ips       = [data.scaleway_ipam_ip.pn_ip[format("%s-1", each.key)].address, data.scaleway_ipam_ip.pn_ip[format("%s-2", each.key)].address]
}

resource "scaleway_lb_frontend" "sql" {
  for_each     = local.regions
  lb_id        = scaleway_lb.lb[each.key].id
  backend_id   = scaleway_lb_backend.sql[each.key].id
  name         = "front-sql"
  inbound_port = "5432"
}

output "servers" {
  value = [for instance in scaleway_instance_server.srv : "${instance.name} ansible_user=root ansible_host=${instance.public_ip} lb_addr=${split("/", scaleway_ipam_ip.vip[join("-", slice(split("-", instance.zone), 0, 2))].address)[0]} locality=region=${join("-", slice(split("-", instance.zone), 0, 2))},zone=${instance.zone}"]
}

