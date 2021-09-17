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