# Terraform config

terraform {

  # backend

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.76.1"
    }
  }
}

# AWS Provider

provider "aws" {

  region = var.region
}

# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

# Create Subnets
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main_gw"
  }
}
# Security group

resource "aws_security_group" "security_terraform" {
  description = "security group for terraform"
  name        = "security_terraform"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #  egress {
  #    from_port = 0
  #    to_port = 65535
  #    protocol = "tcp"
  #    cidr_blocks = ["0.0.0.0/0"]
  #  }

  tags = {
    Name = var.special_tag
  }
}

# Create an AWS launch template

resource "aws_launch_template" "launch_temp" {
  image_id               = var.ami
  instance_type          = var.instance_type
  key_name               = var.key
  depends_on             = [aws_internet_gateway.gw]
  vpc_security_group_ids = [aws_security_group.security_terraform.id]
  user_data              = filebase64("micro_web.sh")
  lifecycle {
    create_before_destroy = true
  }
}



# Create AWS ELB resource

resource "aws_elb" "ELB" {
  subnets = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = var.special_tag
  }
}

# Create an AWS auto scaling group

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id, ]
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  load_balancers      = [aws_elb.ELB.id]
  launch_template {
    id = aws_launch_template.launch_temp.id
  }
}

resource "aws_autoscaling_schedule" "start_time" {
  scheduled_action_name  = "start_time"
  min_size               = 1
  max_size               = 4
  desired_capacity       = 2
  recurrence             = "0 9 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.asg.name
}
resource "aws_autoscaling_schedule" "end_time" {
  scheduled_action_name  = "end_time"
  min_size               = 0
  max_size               = 1
  desired_capacity       = 0
  recurrence             = "0 18 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

output "elb_dns_name" {
  value = aws_elb.ELB.dns_name
}
