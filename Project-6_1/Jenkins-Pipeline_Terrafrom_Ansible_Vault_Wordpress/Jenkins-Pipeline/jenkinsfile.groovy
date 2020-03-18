#!/usr/bin/groovy

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        string(name: 'Project_number', defaultValue: 'Project-6_1')
        string(name: 'Project_name', defaultValue: 'Jenkins-Pipeline_Terrafrom_Ansible_Vault_Wordpress')
   }

   environment {
        PROJECT_PATH = "${params.Project_number}/${params.Project_name}"
    }

    stages {

        stage("Build-WordPress-Infra") {
            steps { buildInfra() }
		}

        stage("Provision-WordPress-With-Ansible") {
            steps { provisionWordPress() }
		}

        stage("Approve-Infra-Teardown") {
            steps { approveTeardown() }
    }

        stage("Teardown-WordPress-Infra") {
            steps { tearDownInfra() }
    }

	}
}


// steps
def buildInfra() {
	dir ('${env.PROJECT_PATH}/Terraform/layers/wordpress' ) {
    sh "chmod +x create-infra.sh"
    sh "./create-infra.sh"
	}
}

def provisionWordPress() {
  dir ('${env.PROJECT_PATH}/Ansible/wordpress-nginx' ) {
    sh "chmod +x ec2.py run.sh"
    sh "./run.sh"
	}
}

def approveTeardown() {
  timeout(time:1, unit:'DAYS') {
		input('Are you sure you want to teardown the WordPress Infra?')
	}
}

def tearDownInfra() {
  dir ('${env.PROJECT_PATH}/Terraform/layers/wordpress' ) {
    sh "chmod +x destroy-infra.sh"
    sh "./destroy-infra.sh"
	}
}
