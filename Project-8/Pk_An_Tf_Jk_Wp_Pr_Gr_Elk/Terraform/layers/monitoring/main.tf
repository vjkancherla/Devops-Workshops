/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "project8-monitoring.tfstate"
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

data "aws_ami" "monitoring-ami" {
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "name"
    values = ["packer-monitoring-*"]
  }
  most_recent = true
  owners = ["self"]
}

module "monitoring-instance" {
  source = "../../modules/aws-terraform-ec2_autorecovery-0.0.23/"

  image_id            = "${data.aws_ami.monitoring-ami.id}"
  additional_tags     = "${merge(local.base_tags,
                            map("Name", "vija0326-monitoring-Amz2"),
                            map("app_tier", "monitoring"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-monitoring-Amz2"
  security_group_list = ["${aws_security_group.monitoring-ec2-sg.id}"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
}


module "clb" {
  source = "../../modules/aws-terraform-clb-0.0.7/"

  # Required
  clb_name        = "vija0326-monitoring"
  security_groups = ["${aws_security_group.monitoring-clb-sg.id}"]
  instances       = ["${module.monitoring-instance.ar_instance_id_list}"]
  instances_count = 1
  subnets         = ["subnet-0655ca5e0722c13ec", "subnet-0207deb52e016cefa"]

  internal_loadbalancer = false

  health_check_target = "TCP:9090"

  # Logging Buckets
  create_logging_bucket = false

  # Rackspace Managed
  rackspace_managed = true


  # One of 'none'|'load_balancer'|'application' and the appropriate block below
  stickiness_type = "none"

  listeners = [
    {
      instance_port     = 9090
      instance_protocol = "HTTP"
      lb_port           = 9090
      lb_protocol       = "HTTP"
    },
    {
      instance_port     = 3000
      instance_protocol = "HTTP"
      lb_port           = 3000
      lb_protocol       = "HTTP"
    },
  ]
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "monitoring-clb-sg" {
  name        = "monitoring-clb-sg"
  description = "Allow monitoring inbound traffic"
  vpc_id      = "vpc-0c6ee31520a0b15fa"

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32", "134.213.178.10/32", "134.213.183.100/32"]
    from_port   = 9090
    protocol    = "tcp"
    to_port     = 9090
  }

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32", "134.213.178.10/32", "134.213.183.100/32"]
    from_port   = 3000
    protocol    = "tcp"
    to_port     = 3000
  }

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port   = 9300
    protocol    = "tcp"
    to_port     = 9300
  }

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port   = 9200
    protocol    = "tcp"
    to_port     = 9200
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = ["ECS-EC2-Example-VPC"]
  }
}

resource "aws_security_group" "monitoring-ec2-sg" {
  name        = "monitoring-ec2-sg"
  description = "Allow monitoring inbound traffic"
  vpc_id      = "${data.aws_vpc.selected_vpc.id}"

  ingress {
    cidr_blocks = ["${data.aws_vpc.selected_vpc.cidr_block}"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    security_groups = ["${aws_security_group.monitoring-clb-sg.id}"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
