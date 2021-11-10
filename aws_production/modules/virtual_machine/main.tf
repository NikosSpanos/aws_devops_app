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
  availability_zone = "eu-west-3a" #data.aws_availability_zones.available.names[0]
  depends_on        = [aws_internet_gateway.gw]

  map_public_ip_on_launch = true

  tags = {
      Name = "main-public-1"
  }
}

resource "aws_subnet" "subnet_prod_id2" {
  vpc_id            = aws_vpc.vpc_prod.id
  cidr_block        = "10.0.2.0/24" //a second subnet can't use the same cidr block as the first subnet
  availability_zone = "eu-west-3b" #data.aws_availability_zones.available.names[1]
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
# ACL inbound
resource "aws_network_acl_rule" "all_inbound_traffic_acl" {
  network_acl_id = aws_network_acl.production_acl_network.id
  rule_number    = 180
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# ACL outbound
resource "aws_network_acl_rule" "all_outbound_traffic_acl" {
  network_acl_id = aws_network_acl.production_acl_network.id
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  rule_number    = 180
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# ---------------------------------------- Step 3: Create security group/ rules ----------------------------------------
resource "aws_security_group" "sg_prod" {
    name   = "production-security-group"
    vpc_id = aws_vpc.vpc_prod.id
}

# Ibound rules
# Create first (inbound) security rule to open port 22 for ssh connection request
resource "aws_security_group_rule" "ssh_inbound_rule_prod" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["94.70.57.33/32", "94.70.57.183/32", "79.129.48.158/32"] #"94.70.57.33/32", "79.129.48.158/32", "192.168.30.22/32", "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 22 for ssh connection"
}

# Create second (inbound) security rule to allow pings of public ip address of ec2 instance from local machine
resource "aws_security_group_rule" "ping_public_ip_sg_rule" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"] #94.70.57.33/32", "79.129.48.158/32", "192.168.30.22/32, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "allow pinging elastic public ipv4 address of ec2 instance from local machine"
}

# Create third (inbound) security rule to open MySQL port 3306 for connection between VM and MySQL db
resource "aws_security_group_rule" "mysql_inbound_rule_prod" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["94.70.57.33/32", "94.70.57.183/32", "79.129.48.158/32"] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 3306 for inbound connection between VM and MySQL server"
}

#--------------------------------

# Outbound rules
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

# Create third (outbound) security rule to open MySQL port 3306 for connection between VM and MySQL db
resource "aws_security_group_rule" "mysql_outbound_rule_prod" {
  depends_on        = [aws_eip.prod_server_public_ip]
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [aws_eip.prod_server_public_ip.public_ip] #aws_vpc.vpc_prod.cidr_block, "0.0.0.0/0"
  security_group_id = aws_security_group.sg_prod.id
  description       = "security rule to open port 3306 for outbound connection between VM and MySQL server"
}

# ---------------------------------------- Step 4: SSH key generated for accessing VM ----------------------------------------
resource "tls_private_key" "ssh_key_prod" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------- Step 5: Generate aws_key_pair ----------------------------------------
resource "aws_key_pair" "generated_key_prod" {
  key_name   = "${var.prefix}-server-ssh-key"
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
  description     = "Production server network interface"

  tags   = {
    Name = "production-network-interface"
  }
}

# ---------------------------------------- Step 7: Create the Elastic Public IP after having created the network interface ----------------------------------------

resource "aws_eip" "prod_server_public_ip" {
  vpc               = true
  network_interface = aws_network_interface.network_interface_prod.id #don't specify both instance and a network_interface id, one of the two!
  
  depends_on        = [aws_internet_gateway.gw, aws_network_interface.network_interface_prod]
  tags   = {
    Name = "production-elastic-ip"
  }
}

# ---------------------------------------- Step 8: Associate public ip to network interface ----------------------------------------

resource "aws_eip_association" "eip_assoc" {
  allocation_id = aws_eip.prod_server_public_ip.id
  network_interface_id = aws_network_interface.network_interface_prod.id # don't use instance_id and network_interface_id at the same time

  depends_on = [aws_eip.prod_server_public_ip, aws_network_interface.network_interface_prod]
}

# ---------------------------------------- Step 9: Create route table with rules ----------------------------------------

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

# Assign internet gateway rule to route table
resource "aws_route" "route_prod_all" {
  route_table_id         = aws_route_table.route_table_prod.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
  depends_on             = [
    aws_route_table.route_table_prod, aws_internet_gateway.gw
  ]
}

# Create main route table association with the two subnets
resource "aws_main_route_table_association" "main-route-table" {
  vpc_id         = aws_vpc.vpc_prod.id
  route_table_id = aws_route_table.route_table_prod.id
}

resource "aws_route_table_association" "main-public-1-a" {
  subnet_id      = aws_subnet.subnet_prod.id
  route_table_id = aws_route_table.route_table_prod.id
}

resource "aws_route_table_association" "main-public-1-b" {
  subnet_id      = aws_subnet.subnet_prod_id2.id
  route_table_id = aws_route_table.route_table_prod.id
}

# ---------------------------------------- Step 10: Create the AWS EC2 instance ----------------------------------------
resource "aws_instance" "production_server" {
  depends_on                  = [aws_eip.prod_server_public_ip, aws_network_interface.network_interface_prod, aws_security_group_rule.ssh_inbound_rule_prod]
  ami                         = "ami-06d79c60d7454e2af" #data.aws_ami.ubuntu-server.id, ami-0a5a9780e8617afe7
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.generated_key_prod.key_name

  #The block below fixes the error of attaching default network interface at index 0 
  network_interface {
    network_interface_id = aws_network_interface.network_interface_prod.id
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
  #   host        = aws_eip.prod_server_public_ip.public_ip //Error: host for provisioner cannot be empty -> https://github.com/hashicorp/terraform-provider-aws/issues/10977
  #   user        = "ubuntu"
  #   private_key = "${chomp(tls_private_key.ssh_key_prod.private_key_pem)}"
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
    sudo apt-get install -y openjdk-11-jdk
    #sudo apt install -y python2
    #sudo curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
    #sudo python2 get-pip.py
    #sudo echo $(python2 --version) & echo $(pip2 --version)
    sudo apt install -y python3 python3-pip
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    pip3 install setuptools
    echo "Modules installed via Terraform"
	EOF

  tags   = {
    Name = "production-server"
  }

  # volume_tags = {
  #   Name      = "production-volume"
  # }
}

# resource "aws_ebs_volume" "production_server_ebs_volume" {
#   availability_zone = "us-east-2"
#   size              = 8
#   type              = "standard"

#   tags   = {
#     Name = "production-volume"
#   }
# }

# resource "aws_volume_attachment" "ebs_attachment" {
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.production_server_ebs_volume.id
#   instance_id = aws_instance.production_server.id
# }