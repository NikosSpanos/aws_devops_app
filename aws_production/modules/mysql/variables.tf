variable "location" {
	description = "Resource group location"
}

variable "location_sg" {
	description = "Resource allocation zone for Security Group (SG) in AWS"
}

variable "prefix" {
  description = "Resource group prefix (i.e development/ production)"
}

variable vm_instance_sg{
	description = "Security group id created in vm instance object"
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