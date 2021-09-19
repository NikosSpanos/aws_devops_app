variable "location" {
	description = "Resource allocation zone in AWS"
    default = "us-east-2a"
}

variable "prefix" {
  description = "Resource group prefix (i.e development/ production)"
}

variable "credentials_path" {
  description = "AWS instance configuration / local path"
  type        = string
  sensitive   = true
}

variable "mysql_master_username" {
  description = "Server administrator username"
  type        = string
  sensitive   = true
}

variable "mysql_master_password" {
  description = "Server administrator password"
  type        = string
  sensitive   = true
}