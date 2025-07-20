# Configure required providers
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

# Read the output from the Traefik project's state file
data "terraform_remote_state" "traefik" {
  backend = "local"
  config = {
    path = "${path.module}/../traefik-terraform/terraform.tfstate"
  }
}

# Define a persistent volume for the database
resource "docker_volume" "db_data" {
  name = "mariadb_data"
}

# Define the MariaDB container
resource "docker_container" "mariadb" {
  image = "mariadb:latest"
  name  = "mariadb"
  networks_advanced {
    name = data.terraform_remote_state.traefik.outputs.network_name
  }
  env = [
    "MARIADB_DATABASE=wordpress",
    "MARIADB_USER=wordpress",
    "MARIADB_PASSWORD=${var.db_password}",
    "MARIADB_ROOT_PASSWORD=${var.db_password}"
  ]
  volumes {
    volume_name    = docker_volume.db_data.name
    container_path = "/var/lib/mysql"
  }
}

# Define the WordPress container
resource "docker_container" "wordpress" {
  depends_on = [docker_container.mariadb]
  image      = "wordpress:latest"
  name       = "wordpress"
  networks_advanced {
    name = data.terraform_remote_state.traefik.outputs.network_name
  }
  env = [
    "WORDPRESS_DB_HOST=mariadb:3306",
    "WORDPRESS_DB_USER=wordpress",
    "WORDPRESS_DB_PASSWORD=${var.db_password}",
    "WORDPRESS_DB_NAME=wordpress"
  ]
  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.wordpress.rule"
    value = "Host(`wordpress.midna.local`)"
  }
  labels {
    label = "traefik.http.routers.wordpress.entrypoints"
    value = "websecure"
  }
  labels {
    label = "traefik.http.routers.wordpress.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.services.wordpress.loadbalancer.server.port"
    value = "80"
  }
  labels {
    label = "traefik.docker.network"
    value = data.terraform_remote_state.traefik.outputs.network_name
  }
}
