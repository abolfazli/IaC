## About The Project

Cloud-native systems embrace microservices, containers, and modern system design to achieve speed and agility. They provide automated build and release stages to ensure consistent and quality code. But, that's only part of the story. How do you provision the cloud environments upon which these systems run?
Modern cloud-native applications embrace the widely accepted practice of Infrastructure as a Code, or IaaC. With IaaC, you automate platform provisioning. You essentially apply software engineering practices such as testing and versioning to your DevOps practices. Your infrastructure and deployments are automated, consistent, and repeatable. Just as continuous delivery automated the traditional model of manual deployments, Infrastructure as a Code (IaaC) is evolving how application environments are managed.

<!-- GETTING STARTED -->
## Getting Started


### Disclaimer
This code is still under development. Do not use it for production purposes. The idea behind this automated code is to bring up an easy LAB to start Palo alto firewall configuration practices.

### Prerequisites

1. Having a gmail account :-)
2. activating your free tier GCP account: https://console.cloud.google.com
3. Done.

<!-- USAGE EXAMPLES -->
### Usage

1. go to: https://console.cloud.google.com
2. select your project if it's not selected.
3. Click on "Activate Cloud Shell"
4. run the following commands:

```
git clone https://github.com/abolfazli/IaC
cd Iac/paloalto-fw-basic-lab
chmod +x start.sh
sh start.sh
```

Have a coffee for 10 minutes and your LAB will be ready
