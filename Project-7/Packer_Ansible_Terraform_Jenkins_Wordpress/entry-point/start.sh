#!/bin/bash

export PATH=$PATH:/Users/vija0326/Downloads/packer-executable:/Users/vija0326/Library/Python/2.7/bin

echo "<<=============================>"
echo ""
echo "Invoking Packer to build the Jenkins AMI"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-7/Packer_Ansible_Terraform_Jenkins_Wordpress/Packer/Jenkins

packer build -force jenkins-ami-builder.json | tee build.log

egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt
grep -i ami ami_id.txt || exit 1

rm build.log ami_id.txt


echo "<<=============================>"
echo ""
echo "Invoking Terraform to build the Jenkins AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-7/Packer_Ansible_Terraform_Jenkins_Wordpress/Terraform/layers/jenkins

terraform init

terraform apply -auto-approve
