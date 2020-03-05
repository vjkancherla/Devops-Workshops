#!/usr/bin/groovy

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    stages {

        stage("Build-WordPress-Infra") {
            steps { buildInfra() }
		}

        stage("Provision-WordPress-With-Ansible") {
            steps { provisionWordPress() }
		}

	}
}


// steps
def buildInfra() {
	dir ('Project-6/Jenkins-Pipeline_Terrafrom_Ansible_Wordpress/Terraform/layers/wordpress' ) {
    sh "chmod +x create-infra.sh"
    sh "./create-infra.sh"
	}
}

def provisionWordPress() {
  dir ('Project-6/Jenkins-Pipeline_Terrafrom_Ansible_Wordpress/Ansible/wordpress-nginx' ) {
    sh "chmod 500 ssh_keys/*"
    sh "chmod +x ec2.py run.sh"
    sh "./run.sh /var/lib/jenkins/workspace/WP-pipeline"
	}
}
