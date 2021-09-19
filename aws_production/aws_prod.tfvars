/*
Terraform variables that should be configured from the user.
Variable 1: prefix 
--description: string text var to distinguish infrastructure from development to production resours
--values accepted: [production, development]

Variable 2: credentials path
--description: the local directory to find the AWS connection credentials
--values accepted: path

Variable 3: location
--description: availability zone of AWS instances
--values accepted: us-east-2a

Issue: For some reason .tfvars file is not recognized by terraform plan. Thus, a variables.tf should be created
*/
prefix = "production"
credentials_path = "$HOME/.aws/credentials"
location = "us-east-2"