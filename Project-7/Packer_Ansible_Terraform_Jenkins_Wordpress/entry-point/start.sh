#!/bin/bash

export PATH=$PATH:/Users/vija0326/Downloads/packer-executable:/Users/vija0326/Library/Python/2.7/bin

echo "<<=============================>"
echo "\n"
echo "Invoking Packer to build the Jenkins AMI"
echo "\n"

cd /Users/vija0326/Downloads/Devops-Workshops/Project-7/Packer_Ansible_Terraform_Jenkins_Wordpress/Packer/Jenkins

packer build jenkins-ami-builder.json | tee build.log

egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt
test -s ami_id.txt || exit 1


echo "<<=============================>"
echo "\n"
echo "Invoking Terraform to build the Jenkins AWS env"
echo "\n"

cd /Users/vija0326/Downloads/Devops-Workshops/Project-7/Packer_Ansible_Terraform_Jenkins_Wordpress/Terraform/layers/jenkins

terraform init

terraform apply -auto-approve
