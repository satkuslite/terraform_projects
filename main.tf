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

# Internet gateway for VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main_gw"
  }
}

# Security group for instances
resource "aws_security_group" "sg_instance" {
  name   = "sg_instance"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
  vpc_security_group_ids = [aws_security_group.sg_instance.id]
  user_data              = filebase64("micro_web.sh")
  lifecycle {
    create_before_destroy = true
  }
}

# Create an AWS load balancer listener and rules
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

# Target group for load balancer
resource "aws_lb_target_group" "test" {
  name     = "testing"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Security group for load balancer
resource "aws_security_group" "sg_alb" {
  name   = "sg_alb"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.special_tag
  }
}


# Initiating Application load balancer itself
resource "aws_lb" "load_balancer" {
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_groups    = [aws_security_group.sg_alb.id]
}

# Autoscaling group
resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id, ]
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.test.arn]
  launch_template {
    id = aws_launch_template.launch_temp.id
  }
}

#Scedule to make autoscaling group turn on and shutdown instances
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
  value = aws_lb.load_balancer.dns_name
}
