# Configure the Microsoft Azure Provider.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "remote" {
    organization = "codehub-spanos"

    workspaces {
      name = "aws_app_prod" //terraform cloud workspace
    }
  }
}

//note: every input variable in main.tf file needs to be declared in a separate variables.tf file. Otherwise, undeclared variable error is generated in terraform plan.

provider "aws"{
      region = var.location //configure aws cli => https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
      access_key = var.aws_access_key
      secret_key = var.aws_secret_key
      //shared_credentials_file = var.credentials_path
      profile = "default"
  }

module "virtual_machines" {
    source = "./modules/virtual_machine"
    location = var.location
    //location_sg = var.location_sg
    prefix = var.prefix
}

module "mysql" {
    source = "./modules/mysql"
    vm_instance_sg = module.virtual_machines.security_group_id
    location = var.location
    //location_sg = var.location_sg
    prefix = var.prefix
    mysql_master_username = var.mysql_master_username
    mysql_master_password = var.mysql_master_password
    ec2_instance_subnet = module.virtual_machines.subnet_id
    subnet_availability_zone = module.virtual_machines.subnet_availability_zone
}