/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "project8-jenkins.tfstate"
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

data "aws_iam_policy_document" "mod_ec2_assume_role_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_policy" "jenkins-instance-policy" {
  name        = "jenkins-instance-policy"
  path        = "/"
  description = "Permissions required for running packer, ansible and terraform"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ansibleperms",
      "Effect": "Allow",
      "Action": [
          "ec2:Describe*",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "rds:Describe*",
          "elasticache:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "terraformperms",
      "Effect": "Allow",
      "Action": [
          "ec2:*",
          "elasticloadbalancing:*",
          "s3:*",
          "logs:*",
          "cloudwatch:*",
          "ssm:*",
          "iam:*",
          "route53:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "packerperms",
      "Effect": "Allow",
      "Action": [
          "iam:PassRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetRole",
          "iam:GetInstanceProfile",
          "iam:DeleteRolePolicy",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:AddRoleToInstanceProfile"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

data "aws_ami" "jenkins-ami" {
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "name"
    values = ["packer-jenkins-*"]
  }
  most_recent = true
  owners = ["self"]
}

module "jenkins-instance" {
  source = "../../modules/aws-terraform-ec2_autorecovery-0.0.23/"

  image_id            = "${data.aws_ami.jenkins-ami.id}"
  additional_tags     = "${merge(local.base_tags,
                            map("Name", "vija0326-jenks-Amz2-Master"),
                            map("app_tier", "jenkins"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-jenks-Amz2-Master"
  security_group_list = ["${aws_security_group.jenkins-ec2-sg.id}"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
  instance_role_managed_policy_arns = ["${aws_iam_policy.jenkins-instance-policy.arn}"]
  instance_role_managed_policy_arn_count = 1
}


module "clb" {
  source = "../../modules/aws-terraform-clb-0.0.7/"

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
