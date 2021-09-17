# Configure the Microsoft Azure Provider.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  provider "aws"{
      region = "us-east-2" //configure aws cli => https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
      shared_credentials_file = var.credentials_path
  }
  backend "remote" {
    organization = "codehub-spanos"

    workspaces {
      name = "aws_app_prod" //terraform cloud workspace
    }
  }
}

module "virtual_machines" {
    source = "./modules/virtual_machine"
    location = var.location
    prefix = var.prefix
    rg = azurerm_resource_group.rg_prod
    admin_username = var.admin_username
    public_ip_cicd_vm = var.public_ip_cicd_vm
    cicd_pipeline_repo_path = var.cicd_pipeline_repo_path
}

module "mysql" {
    source = "./modules/mysql"
    vm_instance = module.virtual_machines
    rg = azurerm_resource_group.rg_prod
    location = var.location
    prefix = var.prefix
    mysql_master_username = var.mysql_master_username
    mysql_master_password = var.mysql_master_password
}