#!/bin/bash

export PATH=$PATH:/Users/vija0326/Downloads/packer-executable:/Users/vija0326/Library/Python/2.7/bin


echo "<<=============================>"
echo ""
echo "Invoking Terraform to DESTROY the Jenkins AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/jenkins

terraform destroy -auto-approve

rm -rf ./.terraform


echo "<<=============================>"
echo ""
echo "Invoking Terraform to DESTROY the Monitoring AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/monitoring

terraform destroy -auto-approve

rm -rf ./.terraform
