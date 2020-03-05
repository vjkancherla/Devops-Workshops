/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "project6-wordpress.tfstate"
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

module "db-instance" {
  source = "../../modules/aws-terraform-ec2_autorecovery-0.0.23/"

  additional_tags     = "${merge(local.base_tags,
                                  map("Name", "vija0326-Ans-Amz2-DB"),
                                  map("app_tier", "database"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-Ans-Amz2-DB"
  security_group_list = ["${aws_security_group.wordpress-ec2-sg.id}"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
}

module "web-instance" {
  source = "../../modules/aws-terraform-ec2_autorecovery-0.0.23/"

  additional_tags     = "${merge(local.base_tags,
                                  map("Name", "vija0326-Ans-Amz2-Web"),
                                  map("app_tier", "web"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-Ans-Amz2-Web"
  security_group_list = ["${aws_security_group.wordpress-ec2-sg.id}"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
}

module "clb" {
  source = "../../modules/aws-terraform-clb-0.0.7/"

  # Required
  clb_name        = "ans-wordpress-test"
  security_groups = ["${aws_security_group.wordpress-clb-sg.id}"]
  instances       = ["${module.web-instance.ar_instance_id_list}"]
  instances_count = 1
  subnets         = ["subnet-0655ca5e0722c13ec", "subnet-0207deb52e016cefa"]

  internal_loadbalancer = false

  # Logging Buckets
  create_logging_bucket     = false

  health_check_target = "TCP:80"

  # Rackspace Managed
  rackspace_managed = true


  # One of 'none'|'load_balancer'|'application' and the appropriate block below
  stickiness_type = "none"

  listeners = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]
}

resource "aws_security_group" "wordpress-clb-sg" {
  name        = "wordpress-clb-sg"
  description = "Allow WP inbound traffic"
  vpc_id      = "vpc-0c6ee31520a0b15fa"

  ingress {
    cidr_blocks = ["78.136.22.232/32", "134.213.183.100/32"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }

  ingress {
    cidr_blocks = ["78.136.22.232/32", "134.213.183.100/32"]
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

data "aws_security_group" "jenkins-ec2-sec-group" {
  name = "jenkins-ec2-sg"
}

resource "aws_security_group" "wordpress-ec2-sg" {
  name        = "wordpress-ec2-sg"
  description = "Allow ec2 WP inbound traffic"
  vpc_id      = "vpc-0c6ee31520a0b15fa"

  ingress {
    security_groups = ["${aws_security_group.wordpress-clb-sg.id}"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    cidr_blocks = ["${data.aws_security_group.jenkins-ec2-sec-group.id}"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
