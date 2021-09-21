output "tls_private_key_private" {
  value = tls_private_key.ssh_key_prod.private_key_pem 
}

output "tls_public_key_public" {
  value = tls_private_key.ssh_key_prod.public_key_pem
}

output "public_ip_address" {
  value = aws_instance.production_server.public_ip
}

output "security_group_id" {
  value = aws_security_group.sg_prod.id
}

output "subnet_id" {
  value = aws_subnet.subnet_prod.id
}

output "ec2_instance_availability_zone" {
  value = aws_instance.production_server.availability_zone
}

output "subnet_availability_zone" {
  value = aws_subnet.subnet_prod.availability_zone
}

# output "eip_address" {
#   value = aws_eip.prod_server_public_ip.public_ip
# }