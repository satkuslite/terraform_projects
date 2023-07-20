variable "region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "av_zones" {
  description = "AWS zones to pick for subnets"
  type        = list(any)
  # default     = [us-east-1a, us-east-1b]
}

variable "special_tag" {
  description = "teg to add for all the recources"
  type        = string
  default     = "testing"
}

variable "ami" {
  description = "ami to use"
  type        = string
  default     = "ami-06b09bfacae1453cb" # Amazon Linux 2023 // us-east-1
}

variable "instance_type" {
  description = "types of instances"
  type        = string
  default     = "t2.micro"
}

variable "key" {
  description = "Name of the ssh key"
  type        = string
  default     = "AF_key"
}

variable "vpc_cidr" {
  description = "cidr for VPC"
  type        = string
  default     = "10.0.0.0/16"
}