locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  namespace     = join("-", [local.project_name, local.environment_name])
  domain_suffix = coalesce(var.infrastructure.domain_suffix, "cluster.local")

  labels = {
    "walrus.seal.io/catalog-name"     = "terraform-docker-mysql"
    "walrus.seal.io/project-id"       = local.project_id
    "walrus.seal.io/environment-id"   = local.environment_id
    "walrus.seal.io/resource-id"      = local.resource_id
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }
}

#
# Ensure
#

data "docker_network" "network" {
  name = var.infrastructure.network_id

  lifecycle {
    postcondition {
      condition     = self.driver == "bridge"
      error_message = "Docker network driver must be bridge"
    }
  }
}

resource "docker_volume" "example" {
  name   = "example"
  driver = "local"
}

locals {
  volume_refer_database_data = {
    schema = "docker:localvolumeclaim"
    params = {
      name = docker_volume.example.name
    }
  }

  database = coalesce(var.database, "mydb")
  username = coalesce(var.username, "rdsuser")
  password = coalesce(var.password, substr(md5(local.username), 0, 16))
}

# create the name with a random suffix.

resource "random_string" "name_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  name     = join("-", [local.resource_name, random_string.name_suffix.result])
  fullname = join("-", [local.namespace, local.name])
}

module "this" {
  source = "github.com/walrus-catalog-sandbox/terraform-docker-containerservice?ref=69ae83a"

  infrastructure = {
    domain_suffix = local.domain_suffix
    network_id    = data.docker_network.network.id
  }

  containers = [
    {
      image     = join(":", ["mysql", var.engine_version])
      resources = var.resources
      envs = [
        {
          name  = "MYSQL_DATABASE"
          value = local.database
        },
        {
          name  = "MYSQL_USER"
          value = local.username
        },
        {
          name  = "MYSQL_PASSWORD"
          value = local.password
        },
        {
          name  = "MYSQL_ROOT_PASSWORD"
          value = local.password
        }
      ]
      mounts = [
        {
          path         = "/var/lib/mysql"
          volume_refer = local.volume_refer_database_data # persistent
        }
      ]
      files = [
        {
          path    = "/docker-entrypoint-initdb.d/init.sql"
          content = try(var.seeding.text.content, null)
        }
      ]
      ports = [
        {
          internal = 3306
          external = 3306
          protocol = "tcp"
        }
      ]
    }
  ]
}

#
# Seed Database.
#

resource "byteset_pipeline" "init_sql" {
  count = try(var.seeding.type, null) == "url" ? 1 : 0

  source = {
    address = try(var.seeding.url.location, null)
  }

  destination = {
    address = format("mysql://root:%s@tcp(127.0.0.1:3306)/%s",
      local.password,
      local.database,
    )
  }
}
