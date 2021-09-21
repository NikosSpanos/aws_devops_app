output "db_address" {
    value = aws_db_instance.mysql_server_prod.address
}

output "db_arn" {
    value = aws_db_instance.mysql_server_prod.arn
}

output "db_domain" {
    value = aws_db_instance.mysql_server_prod.domain
}

output "db_id" {
    value = aws_db_instance.mysql_server_prod.id
}

output "db_name" {
    value = aws_db_instance.mysql_server_prod.name
}

output "db_port" {
    value = aws_db_instance.mysql_server_prod.port
}