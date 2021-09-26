#MySQL DB
output "output_database_name" {
  value = module.mysql.db_name
}

#Virtual machines
output "output_private_key" {
  sensitive = true
  value = module.virtual_machines.tls_private_key
}

output "output_public_key" {
  sensitive = false
  value = module.virtual_machines.tls_public_key
}

output "output_public_ip" {
  value = module.virtual_machines.public_ip_address
}

output "output_public_dns_address" {
  sensitive = true
  value = module.virtual_machines.server_dns_public_address
}

output "output_eip_public_ip" {
  value = module.virtual_machines.eip_address
}
