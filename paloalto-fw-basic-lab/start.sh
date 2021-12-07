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
