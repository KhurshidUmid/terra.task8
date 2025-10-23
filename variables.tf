variable "project_name" {
  description = "The unique project identifier (e.g., cmtr-xv69vdlr)."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where resources will be deployed."
  type        = string
}

variable "ssh_key_name" {
  description = "The name of the pre-existing SSH key pair for instance access."
  type        = string
}

variable "ami_id" {
  description = "The Amazon Machine Image (AMI) ID for the EC2 instances."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type (e.g., t3.micro)."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all provisioned resources."
  type        = map(string)
}
