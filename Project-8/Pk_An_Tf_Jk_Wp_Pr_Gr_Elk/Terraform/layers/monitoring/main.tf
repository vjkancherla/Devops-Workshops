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

data "aws_iam_policy_document" "ec2_assume_role_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_policy" "monitoring_instance_policy" {
  name        = "monitoring-instance-policy"
  path        = "/"
  description = "Permissions required for running monitoring instance"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "monitoringperms",
      "Effect": "Allow",
      "Action": [
          "ec2:Describe*",
          "s3:*",
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ec2_instance_role" {

  assume_role_policy = "${data.aws_iam_policy_document.ec2_assume_role_policy_doc.json}"
  name               = "JenkinsInstanceRole"
  path               = "/"
}

resource "aws_iam_instance_profile" "ec2_instance_role_instance_profile" {

  name = "monitoring_instance_profile"
  path = "/"
  role = "${aws_iam_role.ec2_instance_role.name}"
}

resource "aws_iam_role_policy_attachment" "attach_core_ssm_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "${aws_iam_role.ec2_instance_role.name}"
}

resource "aws_iam_role_policy_attachment" "attach_monitoring_policy" {

  policy_arn = "${aws_iam_policy.monitoring_instance_policy.arn}"
  role       = "${aws_iam_role.mec2_instance_role.name}"
}

resource "aws_instance" "monitoring-instance" {

  ami                    = "${data.aws_ami.monitoring-ami.id}"
  instance_type          = "t3.large"
  subnet_id              = "subnet-09b3316783387f292"
  iam_instance_profile   = "${aws_iam_instance_profile.instance_role_instance_profile.name}"
  vpc_security_group_ids = ["${aws_security_group.monitoring-ec2-sg.id}"]
  key_name               = "VijayKancherla"


  root_block_device {
    volume_type           = "gp2"
    volume_size           = "60"
    delete_on_termination = true
  }

  tags = "${merge(local.base_tags,
                    map("Name", "vija0326-monitoring-Amz2"),
                    map("app_tier", "monitoring"))}"

  provisioner "remote-exec" {
    command = <<EOT
    cd /tmp
    aws s3 cp s3://vija0326-mybucket/ansible-code/monitoring.zip .
    unzip monitoring.zip
    cd monitoring
    ansible-playbook additional-config.yml
EOT
  }
}


module "clb" {
  source = "../../modules/aws-terraform-clb-0.0.7/"

  # Required
  clb_name        = "vija0326-monitoring"
  security_groups = ["${aws_security_group.monitoring-clb-sg.id}"]
  instances       = ["${aws_instance.monitoring-instance.id}"]
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

resource "aws_route53_zone" "internal_zone" {
 name   = "project8.local"
 comment = "Hosted zone for Project8"

 vpc {
    vpc_id = "${data.aws_vpc.selected_vpc.id}"
  }

  tags = "${local.base_tags}"
}

resource "aws_route53_record" "monitoring" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "monitoring.project8.local"
  type    = "A"
  ttl     = "300"
  records = ["${module.monitoring-instance.ar_instance_ip_list}"]
}

resource "aws_route53_record" "elasticsearch" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "elasticsearch.project8.local"
  type    = "A"
  ttl     = "300"
  records = ["${module.monitoring-instance.ar_instance_ip_list}"]
}

resource "aws_route53_record" "kibana" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "kibana.project8.local"
  type    = "A"
  ttl     = "300"
  records = ["${module.monitoring-instance.ar_instance_ip_list}"]
}

resource "aws_route53_record" "prometheus" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "prometheus.project8.local"
  type    = "A"
  ttl     = "300"
  records = ["${module.monitoring-instance.ar_instance_ip_list}"]
}

resource "aws_route53_record" "grafana" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "grafana.project8.local"
  type    = "A"
  ttl     = "300"
  records = ["${module.monitoring-instance.ar_instance_ip_list}"]
}
