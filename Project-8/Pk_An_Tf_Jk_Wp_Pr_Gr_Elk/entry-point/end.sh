#!/bin/bash

export PATH=$PATH:/Users/vija0326/Downloads/packer-executable:/Users/vija0326/Library/Python/2.7/bin

destroy_Monitoring_AWS_Env() {
  echo "<<=============================>"
  echo ""
  echo "Invoking Terraform to DESTROY the Monitoring AWS env"
  echo ""

  cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/monitoring

  terraform destroy -auto-approve | tee destroy_monitoring.log

  if ! grep -i "Destroy complete" destroy_monitoring.log
  then
    echo ""
    echo "-->Monitoring Env Destroy FAILED"
    echo ""
    rm destroy_monitoring.log
    exit 1
  else
    echo ""
    echo "-->Monitoring Env successfully destroyed"
    echo ""
    rm destroy_monitoring.log
  fi

  rm -rf ./.terraform
}


destroy_Jenkins_AWS_Env() {
  echo "<<=============================>"
  echo ""
  echo "Invoking Terraform to DESTROY the Jenkins AWS env"
  echo ""

  cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/jenkins

  terraform destroy -auto-approve | tee destroy_jenkins.log

  if ! grep -i "Destroy complete" destroy_jenkins.log
  then
    echo ""
    echo "-->Jenkins Env Destroy FAILED"
    echo ""
    rm destroy_jenkins.log
    exit 1
  else
    echo ""
    echo "-->Jenkins Env successfully destroyed"
    echo ""
    rm destroy_jenkins.log
  fi

  rm -rf ./.terraform
}


destroy_Monitoring_AWS_Env
destroy_Jenkins_AWS_Env
