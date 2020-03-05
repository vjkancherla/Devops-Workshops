#!/bin/bash

jenk-proj-ws = $1

#for the 2 mins for the DB and Web instances to comeup
sleep 120

ansible-playbook -i ./ec2.py site.yml --extra-vars 'jenkins_project_workspace=${jenk-proj-ws}'
