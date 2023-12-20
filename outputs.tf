locals {
  hosts = [
    format("%s.%s.svc.%s", local.resource_name, local.namespace, local.domain_suffix)
  ]

  endpoints = flatten([
    for c in local.hosts : formatlist("%s:3306", c)
  ])
}

#
# Orchestration
#

output "context" {
  description = "The input context, a map, which is used for orchestration."
  value       = var.context
}

output "refer" {
  description = "The refer, a map, including hosts, ports and account, which is used for dependencies or collaborations."
  sensitive   = true
  value = {
    schema = "docker:mysql"
    params = {
      selector  = local.labels
      hosts     = local.hosts
      ports     = [3306]
      endpoints = local.endpoints
    }
  }
}

#
# Reference
#

output "connection" {
  description = "The connection, a string combined host and port, might be a comma separated string or a single string."
  value       = join(",", local.endpoints)
}

output "address" {
  description = "The address, a string only has host, might be a comma separated string or a single string."
  value       = join(",", local.hosts)
}

output "port" {
  description = "The port of the MySQL service."
  value       = 3306
}

output "database" {
  description = "The name of MySQL database to access."
  value       = local.database
}

output "username" {
  description = "The username of the account to access the database."
  value       = local.username
}

output "password" {
  value       = local.password
  description = "The password of the account to access the database."
  sensitive   = true
}

## UI display

output "endpoints" {
  description = "The endpoints, a list of string combined host and port."
  value       = local.endpoints
}
