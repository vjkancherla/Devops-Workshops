#!/bin/bash

export PATH=$PATH:/Users/vija0326/Downloads/packer-executable:/Users/vija0326/Library/Python/2.7/bin

echo "<<=============================>"
echo ""
echo "-->Checking that the proxy host and port are enabled for Packer to work via RAX VPN"
echo ""
nc -z localhost 1337 > /dev/null 2>&1
if [ $? != 0 ]
then
  echo "-->Packer needs proxy host and port. Open a new Terminal tab and run 'ssh -AD 1337 bastion', and then rerun this script"
  exit 1
fi

echo "<<=============================>"
echo ""
echo "-->Invoking Packer to build the Monitoring AMI"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Packer/monitoring

packer build -timestamp-ui -force monitoring-ami-builder.json | tee build.log

egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt

if ! grep -i ami ami_id.txt
then
  echo ""
  echo "-->Monitoring AMI creation FAILED"
  echo ""
  rm build.log ami_id.txt
  exit 1
else
  rm build.log ami_id.txt
  echo ""
  echo "-->Monitoring AMI successfully created"
  echo ""
fi


echo "<<=============================>"
echo ""
echo "-->Invoking Terraform to build the Monitoring AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/monitoring

rm -rf ./.terraform

terraform init

terraform apply -auto-approve | tee build.log

if ! grep -i "Apply complete" build.log
then
  echo ""
  echo "-->Monitoring Env creation FAILED"
  echo ""
  rm build.log
  exit 1
else
  echo ""
  echo "-->Monitoring Env successfully created"
  echo ""
  rm build.log
fi


echo "<<=============================>"
echo ""
echo "-->Running Shell commands, using SSM, to do additional config on the Monitoring instance"
echo ""

instance_id=`terraform state show "module.monitoring-instance.aws_instance.mod_ec2_instance_no_secondary_ebs" | grep -w id | cut -d "=" -f 2 | sed "s/^ *//g"`

aws ssm send-command --instance-ids "${instance_id}" \
--document-name "AWS-RunShellScript" \
--comment "Perform additional monitoring config" \
--parameters commands="[ \
'cd /tmp', \
'aws s3 cp s3://vija0326-mybucket/ansible-code/monitoring.zip .', \
'unzip monitoring.zip', \
'cd monitoring-standalone', \
'ansible-playbook additional-config.yml' ]" \
--output text \
--query "Command.CommandId" | tee ssm.log


cmd_id=`cat ssm.log`
i=0
while true
do
  cmd_status=`aws ssm list-command-invocations --command-id ${cmd_id} --query "CommandInvocations[0].StatusDetails" | cut -d "\"" -f2`
  echo $cmd_status
  if [ "${cmd_status}" == "InProgress" ]
  then
    if [ ${i} -lt 48 ]
    then
      echo "-->SSM command is still 'In Progress'. Will wait for 240 secs for it to complete. So far, $((i*5)) secs have elapsed"
      sleep 5
      i=$((i+1))
      continue
    else
      echo "SSM command did not complete in 240 secs. Exiting"
      rm ssm.log
      exit 1
    fi
  elif [ "${cmd_status}" == "Failed" ]
    then
      echo "-->SSM command failed. Exiting"
      rm ssm.log
      exit 1
  elif [ "${cmd_status}" == "Success" ]
    then
      echo "-->SSM command successfully completed"
      rm ssm.log
      break
  fi
done


: <<'END'

echo "<<=============================>"
echo ""
echo "-->Invoking Packer to build the Jenkins AMI"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Packer/jenkins

packer build -timestamp-ui -force jenkins-ami-builder.json | tee build.log

egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt
grep -i ami ami_id.txt || exit 1

if ! grep -i ami ami_id.txt
then
  echo ""
  echo "-->Jenkins AMI creation FAILED"
  echo ""
  rm build.log ami_id.txt
  exit 1
else
  rm build.log ami_id.txt
  echo ""
  echo "-->Jenkins AMI successfully created"
  echo ""
fi



echo "<<=============================>"
echo ""
echo "Invoking Terraform to build the Jenkins AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/jenkins

rm -rf ./.terraform

terraform init

terraform apply -auto-approve | tee build.log

if ! grep -i "Apply complete" build.log
then
  echo ""
  echo "-->Jenkins Env creation FAILED"
  echo ""
  rm build.log
  exit 1
else
  echo ""
  echo "-->Jenkins Env successfully created"
  echo ""
  rm build.log
fi
END
