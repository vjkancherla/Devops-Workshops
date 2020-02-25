/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "jenkins-000compute.tfstate"
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

resource "aws_iam_policy" "ansible-policy" {
  name        = "ansible-dynamic-inventory-policy"
  path        = "/"
  description = "Permissions required for running ec2.py on master node"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Demo201505282045",
      "Effect": "Allow",
      "Action": [
          "ec2:Describe*",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "rds:Describe*",
          "elasticache:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

module "jenkins-instance" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_autorecovery//?ref=v0.0.23"

  additional_tags     = "${merge(local.base_tags,
                                  map("Name", "vija0326-jenks-Amz2-Master"),
                                  map("app_tier", "jenkins"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-jenks-Amz2-Master"
  security_group_list = ["${aws_security_group.jenkins-ec2-sg.id}"]
  subnets             = ["subnet-0655ca5e0722c13ec"]
  instance_type       = "t3.large"
  instance_role_managed_policy_arns = ["${aws_iam_policy.ansible-policy.arn}"]
  instance_role_managed_policy_arn_count = 1

}

module "clb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-clb//?ref=v0.0.7"

  # Required
  clb_name        = "vija0326-jenkins-test"
  security_groups = ["${aws_security_group.jenkins-clb-sg.id}"]
  instances       = ["${module.jenkins-instance.ar_instance_id_list}"]
  instances_count = 1
  subnets         = ["subnet-0655ca5e0722c13ec", "subnet-0207deb52e016cefa"]

  internal_loadbalancer = false

  health_check_target = "TCP:8080"

  # Logging Buckets
  create_logging_bucket     = false

  # Rackspace Managed
  rackspace_managed = true


  # One of 'none'|'load_balancer'|'application' and the appropriate block below
  stickiness_type = "none"

  listeners = [
    {
      instance_port     = 8080
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "jenkins-clb-sg" {
  name        = "jenkins-clb-sg"
  description = "Allow Jenkins inbound traffic"
  vpc_id      = "vpc-0c6ee31520a0b15fa"

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
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

resource "aws_security_group" "jenkins-ec2-sg" {
  name        = "jenkins-ec2-sg"
  description = "Allow Jenkins inbound traffic"
  vpc_id      = "vpc-0c6ee31520a0b15fa"

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32", "134.213.183.100/32"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  ingress {
    security_groups = ["${aws_security_group.jenkins-clb-sg.id}"]
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
