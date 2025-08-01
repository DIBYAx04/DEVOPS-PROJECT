variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "eu-north-1"
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "The availability zone for the subnets."
  type        = string
  default     = "eu-north-1a"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instances."
  type        = string
  default     = "ami-042b4708b1d05f512"
}

variable "instance_type" {
  description = "The instance type for the EC2 instances."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the instances."
  type        = string
  default     = "PROJECT-KEY"
}

variable "public_key_path" {
  description = "The path to the public SSH key."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

