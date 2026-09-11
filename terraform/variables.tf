variable "aws_region" {
  description = "AWS region for infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Optional EC2 AMI ID. Leave empty to use latest Ubuntu 24.04 LTS."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 Key Pair name"
  type        = string
  default     = "devops-key"
}

variable "private_key_path" {
  description = "Local path to the PEM key used for SSH. Kept for the lab configuration and local convenience."
  type        = string
  default     = "../devops-key.pem"
}

variable "ssh_cidr" {
  description = "CIDR allowed to connect to SSH. 0.0.0.0/0 is convenient for GitHub-hosted runners but should only be temporary."
  type        = string
  default     = "0.0.0.0/0"
}
