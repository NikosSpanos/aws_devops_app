output "tls_private_key_private" {
  value = tls_private_key.ssh_key_prod.private_key_pem 
}

output "tls_public_key_public" {
  value = tls_private_key.ssh_key_prod.public_key_pem
}

output "public_ip_address" {
  value = aws_instance.production_server.public_ip
}