
jenk-proj-ws=$1
ansible-playbook -i ./ec2.py site.yml --extra-vars "jenkins_project_workspace=${jenk-proj-ws}"
