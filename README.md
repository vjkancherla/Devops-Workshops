# DevOps Workshops

A collection of hands-on DevOps lab projects that build progressively more complex
infrastructure-automation and CI/CD pipelines. Each project centers on a stack of
industry tools (Ansible, Terraform, Jenkins, Packer, HashiCorp Vault and ELK-based
monitoring) and walks through provisioning real infrastructure on AWS and deploying
an application (WordPress).

## What's inside

The repository is organised into numbered projects. Each project has its own folder
and an `INSTRUCTIONS.txt` describing the goals and step-by-step steps to reproduce it.

| Project | Focus |
| ------- | ----- |
| Project-1 | Ansible — first playbook, target preparation, dynamic inventory on AWS |
| Project-2 | Ansible + Terraform |
| Project-3 | Ansible + Jenkins + Terraform |
| Project-4 | Ansible + Jenkins + Terraform with provisioners |
| Project-5 | Terraform + Jenkins + Ansible + WordPress |
| Project-6 | Jenkins pipeline + Terraform + Ansible + WordPress |
| Project-6_1 | Jenkins pipeline + Terraform + Ansible + Vault + WordPress |
| Project-7 | Packer + Ansible + Terraform + Jenkins + WordPress |
| Project-8 | Packer + Ansible + Terraform + Jenkins + WordPress + provisioners + green/red + ELK monitoring |

Supporting reference material is also included:

- `ansible-articles.txt` — reference articles and tutorials for Ansible + Terraform on AWS
- `jenkins-articles.txt` — reference articles for building a Jenkins master–slave CI/CD platform on AWS

## Tools covered

- **Configuration management:** Ansible
- **Infrastructure as code:** Terraform
- **CI/CD:** Jenkins (declarative pipelines, master–slave clusters)
- **Image building:** Packer
- **Secrets management:** HashiCorp Vault
- **Application:** WordPress on AWS
- **Monitoring:** ELK stack

## How to use

Open the relevant project folder and follow its `INSTRUCTIONS.txt` to reproduce the lab.

> **Note:** These are learning labs. Some directories contain generated artifacts
> (e.g. SSH keys, `monitoring.zip`) — treat them as example outputs rather than
> production-ready configurations.
