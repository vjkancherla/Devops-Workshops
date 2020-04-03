/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "project8-throwaway.tfstate"
    region = "eu-west-1"
  }

  required_version = "0.11.14"
}

provider "aws" {
  version = "~> 2.20"
  region = "eu-west-1"
}


locals {
  base_tags = {
    Environment     = "Development"
    Layer           = "000compute"
    ServiceProvider = "Rackspace"
    Terraform       = "true"
    sso             = "vija0326"
  }
}

module "throwaway-instance" {
  source = "../../modules/aws-terraform-ec2_autorecovery-0.0.23/"

  additional_tags     = "${merge(local.base_tags,
                            map("Name", "vija0326-throwaway-Amz2-Master"),
                            map("app_tier", "jenkins"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-throwaway-Amz2-Master"
  security_group_list = ["${aws_security_group.throwaway-ec2-sg.id}"]
  subnets             = ["subnet-0655ca5e0722c13ec"]
  instance_type       = "t3.large"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "throwaway-ec2-sg" {
  name        = "throwaway-ec2-sg"
  description = "Allow throwaway inbound traffic"
  vpc_id      = "vpc-0c6ee31520a0b15fa"

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32", "134.213.178.10/32", "134.213.183.100/32"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
