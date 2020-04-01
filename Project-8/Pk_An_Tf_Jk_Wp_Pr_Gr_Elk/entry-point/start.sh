#!/bin/bash

export PATH=$PATH:/Users/vija0326/Downloads/packer-executable:/Users/vija0326/Library/Python/2.7/bin


: <<'END'
    echo "<<=============================>"
    echo ""
    echo "Invoking Packer to build the Jenkins AMI"
    echo ""

    cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Packer/jenkins

    packer build -force jenkins-ami-builder.json | tee build.log

    egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt
    grep -i ami ami_id.txt || exit 1

    rm build.log ami_id.txt


    echo "<<=============================>"
    echo ""
    echo "Invoking Packer to build the Monitoring AMI"
    echo ""

    cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Packer/monitoring

    packer build -force monitoring-ami-builder.json | tee build.log

    egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt
    grep -i ami ami_id.txt || exit 1

    rm build.log ami_id.txt


echo "<<=============================>"
echo ""
echo "Invoking Terraform to build the Jenkins AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/jenkins

terraform init

terraform apply -auto-approve
END

echo "<<=============================>"
echo ""
echo "Invoking Terraform to build the Monitoring AWS env"
echo ""

cd /Users/vija0326/Downloads/Devops-Workshops/Project-8/Pk_An_Tf_Jk_Wp_Pr_Gr_Elk/Terraform/layers/monitoring

terraform init

terraform apply -auto-approve
