terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.22"
        }
    }
}

provider "aws" {
    region = "us-east-2"
}

resource "aws_vpc" "test-custom-vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support   = true
    tags = {
      "Name" = "multi-tier-vpc"
      "Environment" = "prod"
    }
}

#It will create 2 public subnets in two different availability zones
resource "aws_subnet" "public-sbnts" {
    count = length(var.public_subnets_cidr)
    vpc_id =  aws_vpc.test-custom-vpc.id
    cidr_block = element(var.public_subnets_cidr,count.index)
    availability_zone = element(var.availability_zones,count.index)
    map_public_ip_on_launch = true

    tags = {
        "Name" = "web-subnet-${count.index+1}"
    }
}

#It will create 2 private subnets in two different availability zones
resource "aws_subnet" "private-sbnts" {
    count = length(var.private_subnets_cidr)
    vpc_id = aws_vpc.test-custom-vpc.id
    cidr_block = element(var.private_subnets_cidr,count.index)
    availability_zone = element(var.availability_zones,count.index)
    map_public_ip_on_launch = false

    tags = {
      "Name" = "db-subnet-${count.index+1}"
    }
}

#Virtual router that connects VPC with internet 
#But it will also allow internal traffic from internet
resource "aws_internet_gateway" "web-igw" {
  vpc_id = aws_vpc.test-custom-vpc.id

  tags = {
    Name = "igw-for-web"
  }
}

#Route table spacifies how packets are forwarded between 
#the subnets within our vpc, internet and vpn connection
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test-custom-vpc.id
  tags = {
    "Name" = "rt-for-web"
  }
}

resource "aws_route" "public-route" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web-igw.id
}

resource "aws_route_table_association" "public" {
    count = length(var.public_subnets_cidr)
    subnet_id = element(aws_subnet.public-sbnts.*.id,count.index)
    route_table_id = aws_route_table.public.id 
}

#Elastic ip to associate with nat gateway
resource "aws_eip" "eip-ngw" {
    vpc = true
    depends_on = [aws_internet_gateway.web-igw]
}

#It will allow (out going only access) application in private subnet to
#communicate with the internet. It will also prevent internet application/server
#to communicate with the applications in private subnet
#NAT gateway for web subnet 1
resource "aws_nat_gateway" "web-ngw" {  
    allocation_id = aws_eip.eip-ngw.id
    subnet_id = element(aws_subnet.public-sbnts.*.id, 0)
    depends_on = [
      aws_internet_gateway.web-igw
    ]

    tags = {
      "Name" = "ngw-1-for-web"
    }
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.test-custom-vpc.id

    tags = {
      "Name" = "rt-for-db"
    }
}
resource "aws_route" "private" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.web-ngw.id
}


resource "aws_route_table_association" "private" {
    count = length(var.private_subnets_cidr)
    subnet_id =  element(aws_subnet.private-sbnts.*.id, count.index)
    route_table_id = aws_route_table.private.id
}