terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "6.71.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zone" "available" {
    state = "available"
}

# create VPC
resource "aws_vpc" "assessment-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "assessment-vpc"
  }
}

# create subnet
resource "aws_subnet" "assessment-subnet" {
  vpc_id     = aws_vpc.assessment-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zone.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "assessment-subnet"
  }
}

# create security group
resource "aws_security_group" "assessment-sg" {
  name        = "assessment-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.assessment-vpc.id

  tags = {
    Name = "assessment-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh" {
  security_group_id = aws_security_group.assessment-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow-http" {
  security_group_id = aws_security_group.assessment-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow-all-traffic-ipv4" {
  security_group_id = aws_security_group.assessment-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# create internet gateway
resource "aws_internet_gateway" "assessment-gw" {
  vpc_id = aws_vpc.assessment-vpc.id

  tags = {
    Name = "assessment-gw"
  }
}

# create route tables
resource "aws_route_table" "assessment-rt" {
  vpc_id = aws_vpc.assessment-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.assessment-gw.id
  }

  tags = {
    Name = "assessment-rt"
  }
}

resource "aws_route_table_association" "assessment-rta" {
  subnet_id      = aws_subnet.assessment-subnet.id
  route_table_id = aws_route_table.assessment-rt.id
}

# create EC2 instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "assessment-server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.assessment-sg.id]
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.assessment-subnet.id
  user_data                   = file("setup-nginx.sh")
  user_data_replace_on_change = true
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }

  tags = {
    Name = "assessment-server"
  }
}

output "assessment-server-ip" {
  value = "http://${aws_instance.assessment-server.public_ip}"
}

