variable "vm_instance_sg" {
	description = "Security group id created in vm instance object"
}

variable "ec2_instance_subnet" { 
	description = "Subnet id created in vm instance object"
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

variable "subnet_availability_zone" {
	description = "Availability zone of subnet"
}


variable "ec2_instance_subnet_id2" {
	description = "Second subnet id created in vm instance object"
}