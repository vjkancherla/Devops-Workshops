#!/bin/bash

#the command line arg should be like - /var/lib/jenkins/workspace/WP-pipeline

jenk_proj_ws=$1

echo "sleeping for 2 mins for the DB and Web instances to comeup"
sleep 120

ansible-playbook -i ./ec2.py site.yml --extra-vars jenkins_project_workspace=${jenk_proj_ws} --vault-password-file=/root/vault-pwd.txt
