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
	length  = 5
    lower = true
    upper = false
    special = false
    number = false
}

resource "aws_db_parameter_group" "db_param_group_prod" {
  name   = "rds-pg-prod"
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

resource "aws_db_subnet_group" "default" {
  name       = "db-ec2-subnet-group"
  subnet_ids = [var.ec2_instance_subnet, var.ec2_instance_subnet_id2]

  tags = {
    Name = "DB subnet group"
  }
}

#MySQL Server
resource "aws_db_instance" "mysql_server_prod" {
  allocated_storage      = 5120
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = "${random_string.string_server.result}MysqlDB"
  username               = var.mysql_master_username
  password               = var.mysql_master_password
  parameter_group_name   = aws_db_parameter_group.db_param_group_prod.id
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.vm_instance_sg] //in order to use security group id here, we need to first export it as output in the vm module (where we first created this security group)
  availability_zone      = var.subnet_availability_zone
  db_subnet_group_name   = aws_db_subnet_group.default.name

  tags = {
    Name = "${var.prefix}_mysql_server"
  }
}