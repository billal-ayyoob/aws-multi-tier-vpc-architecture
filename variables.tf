variable "aws_region" {
    type = string
    default = "us-east-2"
}

variable "vpc_cidr" {
    type = string
    default = "10.16.0.0/16"
}

variable "availability_zones" {
    type = list
    default = ["us-east-2a", "us-east-2b"]
}

variable "public_subnets_cidr" {
    type = list
    default = ["10.16.0.0/18", "10.16.64.0/18"]
}

variable "private_subnets_cidr" {
    type = list
    default = ["10.16.128.0/18", "10.16.192.0/18"]
}