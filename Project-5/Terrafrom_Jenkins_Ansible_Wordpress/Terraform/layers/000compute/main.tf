/**
 * # 000compute
 */

terraform {
  backend "s3" {
    bucket = "vija0326-mybucket"
    key    = "project5-000compute.tfstate"
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

resource "aws_iam_policy" "ansible-policy" {
  name        = "ansible-dynamic-inventory-policy"
  path        = "/"
  description = "Permissions required for running ec2.py on master node"

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
          "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "mod_ec2_instance_role" {

  assume_role_policy = "${data.aws_iam_policy_document.mod_ec2_assume_role_policy_doc.json}"
  name               = "JenkinsInstanceRole"
  path               = "/"
}

resource "aws_iam_instance_profile" "instance_role_instance_profile" {

  name = "Jenkins-Instance-Profile"
  path = "/"
  role = "${aws_iam_role.mod_ec2_instance_role.name}"
}

resource "aws_iam_role_policy_attachment" "attach_core_ssm_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "${aws_iam_role.mod_ec2_instance_role.name}"
}

resource "aws_iam_role_policy_attachment" "attach_ansible_policy" {

  policy_arn = "${aws_iam_policy.ansible-policy.arn}"
  role       = "${aws_iam_role.mod_ec2_instance_role.name}"
}

resource "aws_instance" "jenkins-instance" {

  ami                    = "ami-099a8245f5daa82bf"
  instance_type          = "t3.large"
  subnet_id              = "subnet-0655ca5e0722c13ec"
  iam_instance_profile   = "${aws_iam_instance_profile.instance_role_instance_profile.name}"
  vpc_security_group_ids = ["${aws_security_group.jenkins-ec2-sg.id}"]
  key_name               = "VijayKancherla"


  root_block_device {
    volume_type           = "gp2"
    volume_size           = "60"
    delete_on_termination = true
  }

  tags = "${merge(local.base_tags,
                    map("Name", "vija0326-jenks-Amz2-Master"),
                    map("app_tier", "jenkins"))}"

  provisioner "local-exec" {
    command = <<EOT
    sleep 120;
	  >jenkins-ci.ini;
	  echo "[jenkins-ci]" | tee -a jenkins-ci.ini;
	  echo "${aws_instance.jenkins-instance.public_ip}" | tee -a jenkins-ci.ini;
    export ANSIBLE_HOST_KEY_CHECKING=False;
	  ansible-playbook -i jenkins-ci.ini ../../../Ansible/jenkins/provision-jenkins.yml
    rm jenkins-ci.ini
EOT
  }
}


module "clb" {
  source = "../../modules/aws-terraform-clb-0.0.7/"

  # Required
  clb_name        = "vija0326-jenkins-test"
  security_groups = ["${aws_security_group.jenkins-clb-sg.id}"]
  instances       = ["${aws_instance.jenkins-instance.id}"]
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
