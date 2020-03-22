#!/usr/bin/groovy

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        string(name: 'Project_number', defaultValue: 'Project-7')
        string(name: 'Project_name', defaultValue: 'Packer_Ansible_Terraform_Jenkins_Wordpress')
   }

   environment {
        PROJECT_PATH = "${params.Project_number}/${params.Project_name}"
    }

    stages {

      stage("Build-MySQL-AMI") {
          steps { buildMysqlAMI() }
	    }

      stage("Build-Web-AMI") {
          steps { buildWebAMI() }
	     }

      stage("Create-Wordpress-Infra") {
          steps { createInfra() }
      }

      stage("Aprrove-WordPress-Infra-Teardown") {
          steps { approveTeardown() }
      }

      stage("Teardown-WordPress-Infra") {
          steps { tearDownInfra() }
      }

	}
}


// steps
def buildMysqlAMI() {
	dir ("${env.PROJECT_PATH}/Packer/Wordpress/Db") {
    sh "packer build mysql-ami-builder"
	}
}

def buildWebAMI() {
	dir ("${env.PROJECT_PATH}/Packer/Wordpress/Web") {
    sh "packer build web-ami-builder"
	}
}

def createInfra() {
  dir ("${env.PROJECT_PATH}/Terraform/layers/wordpress") {
    sh "chmod +x destroy-infra.sh"
    sh "./creat-infra.sh"
	}
}

def approveTeardown() {
  timeout(time:1, unit:'DAYS') {
		input('Are you sure you want to teardown the WordPress Infra?')
	}
}

def tearDownInfra() {
  dir ("${env.PROJECT_PATH}/Terraform/layers/wordpress") {
    sh "chmod +x destroy-infra.sh"
    sh "./destroy-infra.sh"
	}
}
