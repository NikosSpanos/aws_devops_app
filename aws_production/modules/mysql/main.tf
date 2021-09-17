# Configure the Amazon Web Services provider.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

#Random id generator for unique server names
resource "random_string" "string_server" {
	length  = 8
    lower = true
    upper = false
    special = false
}

resource "aws_db_parameter_group" "db_param_group_prod" {
  name   = "rds_pg_prod"
  family = "mysql5.7"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

#MySQL Server
resource "aws_db_instance" "mysql_server_prod" {
  allocated_storage      = 5120
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = "${random_string.string_server.result}-mysqlDB"
  username               = var.mysql_master_username
  password               = var.mysql_master_password
  parameter_group_name   = aws_db_parameter_group.db_param_group_prod.id
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.vm_instance.sg_prod.id]
  availability_zone      = var.location
}