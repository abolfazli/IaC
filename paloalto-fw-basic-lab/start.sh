#!/bin/bash

ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1

export SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
export PROJECT_ID=$(gcloud projects list --format="value(projectId)")
envsubst < temporary.env > terraform.tfvars

gcloud config set project $PROJECT_ID

gcloud services enable compute.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
gcloud services enable runtimeconfig.googleapis.com

sleep 60s

terraform init
terraform apply -auto-approve

export FIREWALL_MGMT_EXIP=$(gcloud compute instances describe pa-firewall --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Firewall ip address is: $FIREWALL_MGMT_EXIP 

You can now close this cloud shell if you know what to do. If you are new stay with me some more minutes. 
We are going to SSH to this device after 5 minutes when firewall completely boots up and the authentication module become ready. 
Please define a complex password for admin user.

===================================================================
Enter the following commands as you are connected to the firewall.
> configure
# set mgt-config users admin password
Then Enter your password and enter \"commit\" and exit the cli and connect to firewall using URL below:
===================================================================

https://$FIREWALL_MGMT_EXIP


Have fun"

sleep 5m
ssh -o "StrictHostKeyChecking no" -i ~/.ssh/id_rsa admin@$FIREWALL_MGMT_EXIP
