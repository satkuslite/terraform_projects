# Terraform config

terraform {
  required_providers {
    aws = {
    source  = "hashicorp/aws"
    version = "~> 3.76.1"
    }
  }
}

# AWS Provider

provider "aws" {
   
   region = "us-east-1"
 }

# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnets
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
}

# Declare a data source that retrieves the most recent Amazon Machine Image (AMI) 

 data "aws_ami" "ubuntu" {
   most_recent = true
 
   filter {
     name = "name"
     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
   }
 
   filter {
     name = "virtualization-type"
     values = ["hvm"]
   }
 
   owners = ["099720109477"] # Canonical
 }

# Security group

 resource "aws_security_group" "security_terraform" {
   name = "security_terraform"
   vpc_id = "aws_vpc.vpc.id"
   description = "security group for terraform"
 
   ingress {
     from_port = 80
     to_port = 80
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   
   ingress {
     from_port = 22
     to_port = 22
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
 
   egress {
     from_port = 0
     to_port = 65535
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
 
   tags = {
     Name = "sg_terraform"
   }
 }

# Create an AWS launch configuration

 resource "aws_launch_configuration" "launch_conf" {
   image_id = "ami-06b09bfacae1453cb"
   instance_type = "t2.micro"
   key_name = "AF_key"
   security_groups = ["security_terraform"]
 
   lifecycle {
       create_before_destroy = true
   }
 }

# Create an AWS auto scaling group

 resource "aws_autoscaling_group" "asg" {
   availability_zones = ["us-east-1a", "us-east-1b"]
   desired_capacity = 2
   max_size = 4
   min_size = 1
   load_balancers = [aws_elb.ELB.id]
   launch_configuration = aws_launch_configuration.launch_conf.id
 
   lifecycle {
       create_before_destroy = true
   }
 }

# Create AWS ELB resource

 resource "aws_elb" "ELB" {
   name = "ELB"
   availability_zones = ["us-east-1a", "us-east-1b"]
 
   listener {
     instance_port = 80
     instance_protocol = "http"
     lb_port = 80
     lb_protocol = "http"
   }
 
   health_check {
     healthy_threshold = 2
     unhealthy_threshold = 2
     timeout = 3
     target = "HTTP:80/"
     interval = 30
   }
   
   cross_zone_load_balancing = true
   idle_timeout = 400
   connection_draining = true
   connection_draining_timeout = 400
 
   tags = {
     Name = "ELB"
   }
 }

 output "elb_dns_name" {
 value = aws_elb.ELB.dns_name
 }