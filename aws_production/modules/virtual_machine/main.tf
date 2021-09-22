terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Create virtual private cloud (vpc)
resource "aws_vpc" "vpc_prod" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

# Assign gateway to vp
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc_prod.id
}

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.prod_server_public_ip.id
#   subnet_id = aws_subnet.subnet_prod.id
# }

resource "aws_network_acl" "production_acl_network" {
  vpc_id = aws_vpc.vpc_prod.id
}

resource "aws_network_acl_rule" "ssh_acl_rule_prod" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 200
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.vpc_prod.cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "port_acl_rule_prod" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 300
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.vpc_prod.cidr_block
  from_port      = 8080
  to_port        = 8080
}

resource "aws_network_acl_rule" "http_acl_rule_prod" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.vpc_prod.cidr_block
  from_port      = 80
  to_port        = 80
}


# Create subnet
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet_prod" {
  vpc_id            = aws_vpc.vpc_prod.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  
  depends_on        = [aws_internet_gateway.gw]

  tags = {
      Name = "main-public-1"
  }
}

resource "aws_subnet" "subnet_prod_id2" {
  vpc_id            = aws_vpc.vpc_prod.id
  cidr_block        = "10.0.2.0/24" //a second subnet can't use the same cidr block as the first subnet
  availability_zone = data.aws_availability_zones.available.names[1]

  depends_on        = [aws_internet_gateway.gw]

  tags = {
        Name = "main-public-2"
    }
}

# Create security group
resource "aws_security_group" "sg_prod" {
    name   = "${var.prefix}_network_security_group"
    vpc_id = aws_vpc.vpc_prod.id
}

# Create first security rule to open port 22
resource "aws_security_group_rule" "ssh_rule_prod" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.vpc_prod.cidr_block] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description = "security rule to open port 22 for ssh connection"
}

# Create second security rule to open port 8080 for jenkins and the application app
resource "aws_security_group_rule" "port_rule_prod" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.vpc_prod.cidr_block] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description = "security rule to open port 8080 for jenkins and java application connection"
}

resource "aws_security_group_rule" "http_rule_prod" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.vpc_prod.cidr_block] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description = "security rule to open http port 80"
}

resource "aws_security_group_rule" "http_outbound_rule_prod" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description = "security rule to open port 80 for outbound connection with http from remote server"
}

# SSH key generated for accessing VM
resource "tls_private_key" "ssh_key_prod" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "generated_key_prod" {
  key_name   = "${var.prefix}_server_ssh_key"
  public_key = tls_private_key.ssh_key_prod.public_key_openssh

  tags = {
    Name = "SSH key pair for production server"
  }
}

# Create the AWS EC2 instance
data "aws_ami" "ubuntu-server" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20210430"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name = "hypervisor"
    values = ["xen"]
  }

    filter {
    name = "image-type"
    values = ["machine"]
  }
}

# data "template_file" "user_data" {
#   template = file("/home/nspanos/Documents/DevOps_AWS/aws_devops_app/aws_production/modules/virtual_machine/install_modules_1.sh")
# }

resource "aws_instance" "production_server" {
  ami                         = data.aws_ami.ubuntu-server.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.generated_key_prod.key_name
  subnet_id                   = aws_subnet.subnet_prod.id
  vpc_security_group_ids      = [aws_security_group.sg_prod.id]
  associate_public_ip_address = true

  # network_interface {
  #   network_interface_id = aws_network_interface.nic_prod.id
  #   device_index         = 0
  # }

  //user_data = file("install_modules_1.sh")
  //user_data = data.template_file.user_data.rendered

  # user_data= <<EOF
	# 	#! /bin/bash
  #   echo "Installing modules..."
  #   sudo apt-get update
  #   sudo apt-get install -y openjdk-8-jdk
  #   sudo apt install -y python2.7 python-pip
  #   sudo apt install -y docker.io
  #   sudo systemctl start docker
  #   sudo systemctl enable docker
  #   pip install setuptools
  #   echo "Modules installed via Terraform"
	# EOF

  tags = {
    Name = "${var.prefix} server"
  }
}

# Create network interface
resource "aws_network_interface" "nic_prod" {
  subnet_id       = aws_subnet.subnet_prod.id
  security_groups = [aws_security_group.sg_prod.id]

  attachment {
    instance     = aws_instance.production_server.id
    device_index = 1
  }

  tags = { 
    Name = "${var.prefix}_network_interface"
  }
}

resource "aws_eip" "prod_server_public_ip" {
  instance          = aws_instance.production_server.id
  vpc               = true
  depends_on        = [aws_internet_gateway.gw, aws_instance.production_server]
}

resource "aws_route_table" "route_table_prod" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name = "route table for production server"
  }
}

/*documentation =>
https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html#Add_IGW_Routing
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-set-up.html?icmpid=docs_ec2_console#ec2-instance-connect-setup-security-group
*/

#Important block!!!
resource "aws_route" "route_prod_all" {
  route_table_id         = aws_route_table.route_table_prod.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
  depends_on = [
    aws_route_table.route_table_prod
  ]
}

resource "aws_route_table_association" "main-public-1-a" {
  subnet_id      = aws_subnet.subnet_prod.id
  route_table_id = aws_route_table.route_table_prod.id
}

resource "aws_route_table_association" "main-public-1-b" {
  subnet_id      = aws_subnet.subnet_prod_id2.id
  route_table_id = aws_route_table.route_table_prod.id
}

resource "null_resource" "install_modules" {
  depends_on    = [aws_eip.prod_server_public_ip, aws_instance.production_server]
  connection {
    type        = "ssh"
    host        = aws_eip.prod_server_public_ip.public_ip //Error: host for provisioner cannot be empty -> https://github.com/hashicorp/terraform-provider-aws/issues/10977
    user        = "ubuntu"
    private_key = "${chomp(tls_private_key.ssh_key_prod.private_key_pem)}" //tls_private_key.ssh_key_prod.private_key_pem
    timeout     = "6m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Installing modules...'",
      "sudo apt-get update",
      "sudo apt-get install -y openjdk-8-jdk",
      "sudo apt install -y python2.7 python-pip",
      "sudo apt install -y docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "pip install setuptools",
      "echo 'Modules installed via Terraform'"
    ]
    on_failure = fail
  }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt update",
#       "sudo apt-get install -y openjdk-8-jdk",
#       "sudo apt install -y python2.7 python-pip",
#       "pip install setuptools"
#     ]
#     on_failure = fail
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt-get update",
#       "sudo apt install -y docker.io",
#       "sudo systemctl start docker",
#       "sudo systemctl enable docker"
#     ]
#     on_failure = fail
#   }
}
