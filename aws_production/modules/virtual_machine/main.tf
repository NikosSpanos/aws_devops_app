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
  cidr_block = "10.0.0.0/16" #or 10.0.0.0/16
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
      Name = "production-private-cloud"
  }
}

# Assign gateway to vp
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc_prod.id
  
  tags = {
      Name = "production-igw"
  }
}

# ---------------------------------------- Step 1: Create two subnets ----------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet_prod" {
  vpc_id            = aws_vpc.vpc_prod.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  depends_on        = [aws_internet_gateway.gw]

  map_public_ip_on_launch = true

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

# ---------------------------------------- Step 2: Create ACL network/ rules ----------------------------------------
resource "aws_network_acl" "production_acl_network" {
  vpc_id = aws_vpc.vpc_prod.id
  subnet_ids = [aws_subnet.subnet_prod.id, aws_subnet.subnet_prod_id2.id] #assign the created subnets to the acl network otherwirse the NACL is assigned to a default subnet

  tags = {
    Name = "production-network-acl"
  }
}

# Create acl rules for the network

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_network_acl_rule" "http_acl_rule_prod_in" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "https_acl_rule_prod_in" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "ssh_acl_rule_prod_in" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "94.70.57.33/32"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "http_more_public_ip_in" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 130
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8080
  to_port        = 8080
}

resource "aws_network_acl_rule" "ping_acl_rule_prod_in" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 140
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "94.70.57.33/32"
  icmp_type      = 42
  icmp_code      = 0
}

# ACL outbound
resource "aws_network_acl_rule" "http_acl_rule_prod_out" {
  network_acl_id = aws_network_acl.production_acl_network.id
  egress         = true
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "https_acl_rule_prod_out" {
  network_acl_id = aws_network_acl.production_acl_network.id
  egress         = true
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "ping_public_ip_out" {
  network_acl_id = aws_network_acl.production_acl_network.id
  egress         = true
  rule_number   = 130
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8080
  to_port        = 8080
}

resource "aws_network_acl_rule" "port_acl_rule_prod_out" {
  network_acl_id = aws_network_acl.production_acl_network.id
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  rule_number    = 150
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# ---------------------------------------- Step 3: Create security group/ rules ----------------------------------------
resource "aws_security_group" "sg_prod" {
    name   = "production-security-group"
    vpc_id = aws_vpc.vpc_prod.id
}

# Create first (inbound) security rule to open port 22 for ssh connection request
resource "aws_security_group_rule" "ssh_inbound_rule_prod" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["94.70.57.33/32"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 22 for ssh connection"
}

# Create second (inbound) security rule to open port 8080 for jenkins and the application app
resource "aws_security_group_rule" "internet_inbound_rule_prod" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 8080 for jenkins and java application connection"
}

# Create third (inbound) security rule to open port 80 for HTTP requests
resource "aws_security_group_rule" "http_inbound_rule_prod" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open http port 80"
}

# Create fourth (inbound) security rule to open port 443 for HTTPS requests
resource "aws_security_group_rule" "https_inbound_rule_prod" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open https port 443"
}

# Create fifth (inbound) security rule to allow pings of public ip address of ec2 instance from local machine
resource "aws_security_group_rule" "ping_public_ip_sg_rule" {
  type              = "ingress"
  from_port         = 42
  to_port           = 42
  protocol          = "icmp"
  cidr_blocks       = ["94.70.57.33/32"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "allow pinging elastic public ipv4 address of ec2 instance from local machine"
}

#--------------------------------

# Create first (outbound) security rule to open port 80 for HTTP requests (this will help to download packages while connected to vm)
resource "aws_security_group_rule" "http_outbound_rule_prod" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 80 for outbound connection with http from remote server"
}

# Create second (outbound) security rule to open port 443 for HTTPS requests
resource "aws_security_group_rule" "https_outbound_rule_prod" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 443 for outbound connection with https from remote server"
}

# ---------------------------------------- Step 4: SSH key generated for accessing VM ----------------------------------------
resource "tls_private_key" "ssh_key_prod" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------- Step 5: Generate aws_key_pair ----------------------------------------
resource "aws_key_pair" "generated_key_prod" {
  key_name   = "${var.prefix}_server_ssh_key"
  public_key = tls_private_key.ssh_key_prod.public_key_openssh

  tags   = {
    Name = "SSH key pair for production server"
  }
}

# ---------------------------------------- Step 6: Create network interface ----------------------------------------

# Create network interface
resource "aws_network_interface" "network_interface_prod" {
  subnet_id       = aws_subnet.subnet_prod.id
  security_groups = [aws_security_group.sg_prod.id]
  #private_ip      = aws_eip.prod_server_public_ip.private_ip #!!! not sure ig this argument is correct !!!
  description     = "Production server network interface"

  tags   = {
    Name = "production-network-interface"
  }
}

# ---------------------------------------- Step 7: Create route table with rules ----------------------------------------

resource "aws_route_table" "route_table_prod" {
  vpc_id = aws_vpc.vpc_prod.id
  tags   = {
    Name = "route-table-production-server"
  }
}

/*documentation =>
https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html#Add_IGW_Routing
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-set-up.html?icmpid=docs_ec2_console#ec2-instance-connect-setup-security-group
*/

#Important block!!! -- First rule of the table (allow all routes)
resource "aws_route" "route_prod_all" {
  route_table_id         = aws_route_table.route_table_prod.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
  depends_on             = [
    aws_route_table.route_table_prod, aws_internet_gateway.gw
  ]
}

# Create main route table association with the two subnets
resource "aws_main_route_table_association" "main-public-1-a" {
  vpc_id         = aws_vpc.vpc_prod.id
  route_table_id = aws_route_table.route_table_prod.id
}

resource "aws_route_table_association" "main-public-1-b" {
  subnet_id      = aws_subnet.subnet_prod_id2.id
  route_table_id = aws_route_table.route_table_prod.id
}

# ---------------------------------------- Step 8: Create the AWS EC2 instance ----------------------------------------
data "aws_ami" "ubuntu-server" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
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

resource "aws_instance" "production_server" {
  ami                         = "ami-0a5a9780e8617afe7" #data.aws_ami.ubuntu-server.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.generated_key_prod.key_name
  #availability_zone           = data.aws_availability_zones.available.names[0] => did not fix account verification error
  subnet_id                   = aws_subnet.subnet_prod.id
  vpc_security_group_ids      = [aws_security_group.sg_prod.id]

  #----Notes regarding network interface block---
  #if network_interface block is specified then subnet_id and vpc_security_group_ids should not be specified, because they will cause a conflict configuration error
  #alternatively use aws_network_interafce and aws_network_interface_attachment blocks
  #Block below might cause account verification error
  # network_interface {
  #   network_interface_id = aws_network_interface.network_interface_prod.id
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

  tags   = {
    Name = "production-server"
  }
}

resource "aws_network_interface_attachment" "eni-server-attachment" {
  instance_id          = aws_instance.production_server.id
  network_interface_id = aws_network_interface.network_interface_prod.id
  device_index         = 0
}

# ---------------------------------------- Step 9: Create the Elastic Public IP ----------------------------------------

resource "aws_eip" "prod_server_public_ip" {
  vpc               = true
  instance          = aws_instance.production_server.id
  #network_interface = aws_network_interface.network_interface_prod.id
  #don't specify both instance and a network_interface id, one of the two!
  
  depends_on        = [aws_internet_gateway.gw, aws_instance.production_server]
  tags   = {
    Name = "production-elastic-ip"
  }
}

# ---------------------------------------- Step 10: Associate public ip to instance or network interface ----------------------------------------

resource "aws_eip_association" "eip_assoc" {
  #dont use instance, network_interface_id at the same time
  instance_id   = aws_instance.production_server.id
  allocation_id = aws_eip.prod_server_public_ip.id
  #network_interface_id = aws_network_interface.nic_prod.id
}

# ---------------------------------------- Step 11: Install modules in production server ----------------------------------------

resource "null_resource" "install_modules" {
  depends_on    = [aws_eip.prod_server_public_ip, aws_instance.production_server]
  connection {
    type        = "ssh"
    host        = aws_eip.prod_server_public_ip.public_ip //Error: host for provisioner cannot be empty -> https://github.com/hashicorp/terraform-provider-aws/issues/10977
    user        = "ubuntu"
    private_key = "${chomp(tls_private_key.ssh_key_prod.private_key_pem)}" //tls_private_key.ssh_key_prod.private_key_pem
    timeout     = "1m"
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
