terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

locals {
  name        = "app"
  environment = "test"
  region      = "nyc3"
}

resource "digitalocean_ssh_key" "default" {
  name       = "Terraform Example"
  public_key = file("~/.ssh/vultr01.pub")
}

resource "digitalocean_vpc" "my_vpc_net" {
  name     = "my-tfhexlet-network"
  region   = local.region
  ip_range = "10.10.11.0/24"
}

resource "digitalocean_database_cluster" "dbcluster" {
  name                 = "example-cluster"
  engine               = "pg"
  version              = "15"
  size                 = "db-s-1vcpu-1gb"
  region               = local.region
  node_count           = 1
  private_network_uuid = digitalocean_vpc.my_vpc_net.id
  depends_on           = [digitalocean_vpc.my_vpc_net]
}

resource "digitalocean_database_db" "example_db" {
  cluster_id = digitalocean_database_cluster.dbcluster.id
  name       = "example_db"
}

resource "digitalocean_database_user" "example_user" {
  cluster_id = digitalocean_database_cluster.dbcluster.id
  name       = "example_user"
}

resource "digitalocean_database_firewall" "example_firewall" {
  cluster_id = digitalocean_database_cluster.dbcluster.id

  rule {
    type  = "droplet"
    value = digitalocean_droplet.vm.id
  }
}

data "digitalocean_database_ca" "ca" {
  cluster_id = digitalocean_database_cluster.dbcluster.id
}

output "host" {
  value = digitalocean_database_cluster.dbcluster.host
}

output "port" {
  value = digitalocean_database_cluster.dbcluster.port
}

output "database_name" {
  value = digitalocean_database_db.example_db.name
}

output "user" {
  value = digitalocean_database_user.example_user.name
}

output "ca" {
  value = data.digitalocean_database_ca.ca.certificate
}

resource "digitalocean_droplet" "vm" {
  depends_on = [digitalocean_database_cluster.dbcluster]
  image      = "docker-20-04"
  name       = "vm-1"
  region     = local.region
  size       = "s-1vcpu-1gb"
  vpc_uuid   = digitalocean_vpc.my_vpc_net.id
  ssh_keys   = [digitalocean_ssh_key.default.fingerprint]

  connection {
    host    = self.ipv4_address
    user    = "root"
    type    = "ssh"
    agent   = true
    timeout = "2m"
  }

  provisioner "remote-exec" {
    inline = ["sudo docker run -d -p 0.0.0.0:80:3000 -e DB_TYPE=postgres -e DB_SSL=1 -e DB_SSL_CA=${data.digitalocean_database_ca.ca.certificate} -e DB_NAME=${digitalocean_database_cluster.dbcluster.database} -e DB_HOST=${digitalocean_database_cluster.dbcluster.host} -e DB_PORT=${digitalocean_database_cluster.dbcluster.port} -e DB_USER=${digitalocean_database_cluster.dbcluster.user} -e DB_PASS=${digitalocean_database_cluster.dbcluster.password} ghcr.io/requarks/wiki:2.5"]
  }
}

