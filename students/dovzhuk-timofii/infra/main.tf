terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    key          = "dovhuk-node-ci/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# If ami_id is empty, use the latest official Ubuntu 24.04 LTS image.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  selected_ami = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
}

resource "aws_security_group" "nodeapp_sg" {
  name        = "nodeapp-terraform-sg"
  description = "Security group for Node.js Docker application"

  tags = {
    Name      = "nodeapp-terraform-sg"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.nodeapp_sg.id
  cidr_ipv4         = var.ssh_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "SSH access"
}

resource "aws_vpc_security_group_ingress_rule" "nodeapp" {
  security_group_id = aws_security_group.nodeapp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  ip_protocol       = "tcp"
  to_port           = 3000
  description       = "Node.js application"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.nodeapp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

resource "aws_instance" "nodeapp" {
  ami                         = local.selected_ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.nodeapp_sg.id]
  associate_public_ip_address = true

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }

  tags = {
    Name      = "nodeapp-terraform"
    ManagedBy = "Terraform"
  }
}

