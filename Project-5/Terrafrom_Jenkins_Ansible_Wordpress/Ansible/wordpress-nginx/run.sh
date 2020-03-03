
jenk-proj-ws=$1
ansible-playbook -i ../ec2.py site.yml --extra-vars "jenkins-project-workspace=${jenk-proj-ws}"
