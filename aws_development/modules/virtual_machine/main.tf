terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Create virtual private cloud (vpc)
resource "aws_vpc" "vpc_dev" {
  cidr_block = "10.0.0.0/16" #or 10.0.0.0/16
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
      Name = "development-private-cloud"
  }
}

# Assign gateway to vp
resource "aws_internet_gateway" "gw_dev" {
  vpc_id = aws_vpc.vpc_dev.id
  
  tags = {
      Name = "development-igw"
  }
}

# ---------------------------------------- Step 1: Create two subnets ----------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet_dev" {
  vpc_id            = aws_vpc.vpc_dev.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a" #data.aws_availability_zones.available.names[0]
  depends_on        = [aws_internet_gateway.gw_dev]

  map_public_ip_on_launch = true

  tags = {
      Name = "dev-public-1"
  }
}

resource "aws_subnet" "subnet_dev_id2" {
  vpc_id            = aws_vpc.vpc_dev.id
  cidr_block        = "10.0.2.0/24" //a second subnet can't use the same cidr block as the first subnet
  availability_zone = "us-east-2b" #data.aws_availability_zones.available.names[1]
  depends_on        = [aws_internet_gateway.gw_dev]

  tags = {
        Name = "dev-public-2"
    }
}

# ---------------------------------------- Step 2: Create ACL network/ rules ----------------------------------------
resource "aws_network_acl" "development_acl_network" {
  vpc_id = aws_vpc.vpc_dev.id
  subnet_ids = [aws_subnet.subnet_dev.id, aws_subnet.subnet_dev_id2.id] #assign the created subnets to the acl network otherwirse the NACL is assigned to a default subnet

  tags = {
    Name = "development-network-acl"
  }
}

# Create acl rules for the network
# ACL inbound
resource "aws_network_acl_rule" "all_inbound_traffic_acl_dev" {
  network_acl_id = aws_network_acl.development_acl_network.id
  rule_number    = 180
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# ACL outbound
resource "aws_network_acl_rule" "all_outbound_traffic_acl_dev" {
  network_acl_id = aws_network_acl.development_acl_network.id
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  rule_number    = 180
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# ---------------------------------------- Step 3: Create security group/ rules ----------------------------------------
resource "aws_security_group" "sg_dev" {
    name   = "development-security-group"
    vpc_id = aws_vpc.vpc_dev.id
}

# Inbound rules
# Create first (inbound) security rule to open port 22 for ssh connection request
resource "aws_security_group_rule" "ssh_inbound_rule_dev" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["94.70.57.33/32", "79.129.48.158/32"] #"94.70.57.33/32", "79.129.48.158/32", "192.168.30.22/32", "0.0.0.0/0"
  security_group_id = aws_security_group.sg_dev.id
  description       = "security rule to open port 22 for ssh connection"
}

# Create fifth (inbound) security rule to allow pings of public ip address of ec2 instance from local machine
resource "aws_security_group_rule" "ping_public_ip_sg_rule_dev" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"] #94.70.57.33/32", "79.129.48.158/32", "192.168.30.22/32, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_dev.id
  description       = "allow pinging elastic public ipv4 address of ec2 instance from local machine"
}

#--------------------------------

# Outbound rules
# Create first (outbound) security rule to open port 80 for HTTP requests (this will help to download packages while connected to vm)
resource "aws_security_group_rule" "http_outbound_rule_dev" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_dev.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_dev.id
  description       = "security rule to open port 80 for outbound connection with http from remote server"
}

# Create second (outbound) security rule to open port 443 for HTTPS requests
resource "aws_security_group_rule" "https_outbound_rule_dev" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #aws_vpc.vpc_dev.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_dev.id
  description       = "security rule to open port 443 for outbound connection with https from remote server"
}

# ---------------------------------------- Step 4: SSH key generated for accessing VM ----------------------------------------
resource "tls_private_key" "ssh_key_dev" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------- Step 5: Generate aws_key_pair ----------------------------------------
resource "aws_key_pair" "generated_key_dev" {
  key_name   = "${var.prefix}-server-ssh-key"
  public_key = tls_private_key.ssh_key_dev.public_key_openssh

  tags   = {
    Name = "SSH key pair for development server"
  }
}

# ---------------------------------------- Step 6: Create network interface ----------------------------------------

# Create network interface
resource "aws_network_interface" "network_interface_dev" {
  subnet_id       = aws_subnet.subnet_dev.id
  security_groups = [aws_security_group.sg_dev.id]
  description     = "development server network interface"

  tags   = {
    Name = "development-network-interface"
  }
}

# ---------------------------------------- Step 7: Create the Elastic Public IP after having created the network interface ----------------------------------------

resource "aws_eip" "dev_server_public_ip" {
  vpc               = true
  network_interface = aws_network_interface.network_interface_dev.id #don't specify both instance and a network_interface id, one of the two!
  
  depends_on        = [aws_internet_gateway.gw_dev, aws_network_interface.network_interface_dev]
  tags   = {
    Name = "development-elastic-ip"
  }
}

# ---------------------------------------- Step 8: Associate public ip to network interface ----------------------------------------

resource "aws_eip_association" "eip_assoc_dev" {
  allocation_id = aws_eip.dev_server_public_ip.id
  network_interface_id = aws_network_interface.network_interface_dev.id # don't use instance_id and network_interface_id at the same time

  depends_on = [aws_eip.dev_server_public_ip, aws_network_interface.network_interface_dev]
}

# ---------------------------------------- Step 9: Create route table with rules ----------------------------------------

resource "aws_route_table" "route_table_dev" {
  vpc_id = aws_vpc.vpc_dev.id
  tags   = {
    Name = "route-table-development-server"
  }
}

/*documentation =>
https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html#Add_IGW_Routing
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-set-up.html?icmpid=docs_ec2_console#ec2-instance-connect-setup-security-group
*/

# Assign internet gateway rule to route table
resource "aws_route" "route_dev_all" {
  route_table_id         = aws_route_table.route_table_dev.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw_dev.id
  depends_on             = [
    aws_route_table.route_table_dev, aws_internet_gateway.gw_dev
  ]
}

# Create main route table association with the two subnets
resource "aws_main_route_table_association" "dev-route-table" {
  vpc_id         = aws_vpc.vpc_dev.id
  route_table_id = aws_route_table.route_table_dev.id
}

resource "aws_route_table_association" "dev-public-1-a" {
  subnet_id      = aws_subnet.subnet_dev.id
  route_table_id = aws_route_table.route_table_dev.id
}

resource "aws_route_table_association" "dev-public-1-b" {
  subnet_id      = aws_subnet.subnet_dev_id2.id
  route_table_id = aws_route_table.route_table_dev.id
}

# ---------------------------------------- Step 10: Create the AWS EC2 instance ----------------------------------------
resource "aws_instance" "development_server" {
  depends_on                  = [aws_eip.dev_server_public_ip, aws_network_interface.network_interface_dev, aws_security_group_rule.ssh_inbound_rule_dev]
  ami                         = "ami-00399ec92321828f5" #data.aws_ami.ubuntu-server.id, ami-0a5a9780e8617afe7
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.generated_key_dev.key_name

  #The block below fixes the error of attaching default network interface at index 0 
  network_interface {
    network_interface_id = aws_network_interface.network_interface_dev.id
    device_index         = 0
  }

  # ebs_block_device {
  #   device_name = "/dev/sda1"
  #   volume_type = "standard"
  #   volume_size = 8
  # }

  # Remote-exec seems to work only if all inbound traffic is allowed to ssh port of the ec2 instance
  # connection {
  #   type        = "ssh"
  #   host        = aws_eip.dev_server_public_ip.public_ip //Error: host for provisioner cannot be empty -> https://github.com/hashicorp/terraform-provider-aws/issues/10977
  #   user        = "ubuntu"
  #   private_key = "${chomp(tls_private_key.ssh_key_dev.private_key_pem)}"
  #   timeout     = "1m"
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "echo Installing modules...",
  #     "sudo apt-get update",
  #     "sudo apt-get install -y openjdk-8-jdk",
  #     "sudo apt install -y python2",
  #     "sudo curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py",
  #     "sudo python2 get-pip.py",
  #     "sudo echo $(python2 --version) & echo $(pip2 --version)",
  #     "sudo apt install -y docker.io",
  #     "sudo systemctl start docker",
  #     "sudo systemctl enable docker",
  #     "pip install setuptools",
  #     "echo Modules installed via Terraform"
  #   ]
  #   on_failure = fail
  # }

  # User_data seems to work with the predefined ip address that have access only to the ssh port of the ec2 instance
  user_data= <<-EOF
		#! /bin/bash
    echo "Installing modules..."
    sudo apt-get update
    sudo apt-get install -y openjdk-8-jdk
    sudo apt install -y python2
    sudo curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
    sudo python2 get-pip.py
    sudo echo $(python2 --version) & echo $(pip2 --version)
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    pip install setuptools
    echo "Modules installed via Terraform"
	EOF

  tags   = {
    Name = "development-server"
  }

  # volume_tags = {
  #   Name      = "development-volume"
  # }
}

# resource "aws_ebs_volume" "development_server_ebs_volume" {
#   availability_zone = "us-east-2"
#   size              = 8
#   type              = "standard"

#   tags   = {
#     Name = "development-volume"
#   }
# }

# resource "aws_volume_attachment" "ebs_attachment" {
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.development_server_ebs_volume.id
#   instance_id = aws_instance.development_server.id
# }