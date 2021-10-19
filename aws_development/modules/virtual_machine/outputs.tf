output "tls_private_key" {
  value = tls_private_key.ssh_key_dev.private_key_pem 
}

output "tls_public_key" {
  value = tls_private_key.ssh_key_dev.public_key_pem
}

output "public_ip_address" {
  value = aws_instance.development_server.public_ip
}

output "security_group_id" {
  value = aws_security_group.sg_dev.id
}

output "subnet_id" {
  value = aws_subnet.subnet_dev.id
}

output "ec2_instance_availability_zone" {
  value = aws_instance.development_server.availability_zone
}

output "subnet_availability_zone" {
  value = aws_subnet.subnet_dev.availability_zone
}

output "eip_address" {
  value = aws_eip.dev_server_public_ip.public_ip
}

output "subnet_id2" {
  value = aws_subnet.subnet_dev_id2.id
}

output "server_dns_public_address" {
  value = aws_instance.development_server.public_dns
}