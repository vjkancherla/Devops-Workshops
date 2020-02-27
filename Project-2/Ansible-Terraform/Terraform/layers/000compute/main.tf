/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "project2-000compute.tfstate"
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

module "master-instance" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_autorecovery//?ref=v0.0.23"

  additional_tags     = "${merge(local.base_tags,
                                  map("Name", "vija0326-Ans-Amz2-Master"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-Ans-Amz2-Master"
  security_group_list = ["sg-0b6a2859c4532d73c"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
  instance_role_managed_policy_arns = ["${aws_iam_policy.ansible-policy.arn}"]
  instance_role_managed_policy_arn_count = 1

  final_userdata_commands = <<EOF
    yum install -y python27, git
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py --user
    /root/.local/bin/pip install ansible
    /root/.local/bin/pip install boto
    cd /root
    git clone https://github.com/vjkancherla/ansible.git
    chmod +x /root/ansible/ec2.py
    chmod +x /root/ansible/wordpress-nginx/run.sh
    chmod 500 /root/ansible/wordpress/ssh_keys/ec2-user-privatekey.pem
EOF
}

module "db-instance" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_autorecovery//?ref=v0.0.23"

  additional_tags     = "${merge(local.base_tags,
                                  map("Name", "vija0326-Ans-Amz2-DB"),
                                  map("app_tier", "database"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-Ans-Amz2-DB"
  security_group_list = ["sg-0b6a2859c4532d73c"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
}

module "web-instance" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_autorecovery//?ref=v0.0.23"

  additional_tags     = "${merge(local.base_tags,
                                  map("Name", "vija0326-Ans-Amz2-Web"),
                                  map("app_tier", "web"))}"
  key_pair            = "VijayKancherla"
  ec2_os              = "amazon2"
  resource_name       = "vija0326-Ans-Amz2-Web"
  security_group_list = ["sg-0b6a2859c4532d73c"]
  subnets             = ["subnet-09b3316783387f292"]
  instance_type       = "t3.large"
}

module "clb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-clb//?ref=v0.0.7"

  # Required
  clb_name        = "ans-wordpress-test"
  security_groups = ["sg-0b6a2859c4532d73c"]
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

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group_rule" "allow_http" {
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  cidr_blocks = ["${chomp(data.http.myip.body)}/32"]

  security_group_id = "sg-0b6a2859c4532d73c"
}
