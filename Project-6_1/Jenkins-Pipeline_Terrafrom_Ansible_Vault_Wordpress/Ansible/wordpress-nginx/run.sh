#!/bin/bash

echo "sleeping for 2 mins for the DB and Web instances to comeup"
sleep 120

ansible-playbook -i ./ec2.py site.yml
