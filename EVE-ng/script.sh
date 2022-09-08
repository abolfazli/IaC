# STILL IN TEST AND EDIT MODE!!!

#!/bin/bash

# Defining Evrironment Variables
#==========================================
clear
echo "-------------------------------------"
echo "--> Setting up environment variables."
echo "-------------------------------------"
PROJECT_ID=$(gcloud projects list --format="value(projectId)" | head -n1)

gcloud config set project $PROJECT_ID

ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1
SSH_KEY=$(cat .ssh/id_rsa.pub)

export REGION="us-central1"
export ZONE="us-central1-a"
export INSTANCE_NAME="eve-ng"

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

export TRUST_NET_NAME="trust"
export UNTRUST_NET_NAME="untrust"

export TRUST_NET_RNG="192.168.1.0/24"
export UNTRUST_NET_RNG="192.168.2.0/24"
echo "Done."
sleep 2s

# Enable Needed APIs for PA and Instances
#==========================================
clear
echo "-------------------------"
echo "--> Enabling system APIs."
echo "-------------------------"
gcloud services enable compute.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
gcloud services enable runtimeconfig.googleapis.com
echo "Done."
sleep 2s

# Creating 4 networks (Management, Trust, Untrust, DMZ)
#==========================================
clear
echo "--------------------------"
echo "--> Creating VPC networks."
echo "--------------------------"
sleep 1s
gcloud compute networks create $TRUST_NET_NAME --project=$PROJECT_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional && gcloud compute networks subnets create $TRUST_NET_NAME --project=$PROJECT_ID --range=$TRUST_NET_RNG --network=$TRUST_NET_NAME --region=$REGION
clear
gcloud compute networks create $UNTRUST_NET_NAME --project=$PROJECT_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional && gcloud compute networks subnets create $UNTRUST_NET_NAME --project=$PROJECT_ID --range=$UNTRUST_NET_RNG --network=$UNTRUST_NET_NAME --region=$REGION
clear
sleep 2s

# Creating 2 firewall rules to allow all traffics
#==========================================
clear
echo "----------------------------"
echo "--> Creating Firewall rules."
echo "----------------------------"
sleep 1s

gcloud compute --project=$PROJECT_ID firewall-rules create ingress-eve --direction=INGRESS --priority=1000 --network=$TRUST_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
clear
gcloud compute --project=$PROJECT_ID firewall-rules create egress-eve --direction=EGRESS --priority=1000 --network=$TRUST_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
clear
sleep 2s

# Creating PC instance in Trust and DMZ
#==========================================
clear
echo "-----------------------------------"
echo "--> Creating PC Instances instance."
echo "-----------------------------------"
sleep 1s
gcloud compute images create nested-ubuntu-focal \
        --source-image-family=ubuntu-2004-lts \
        --source-image-project=ubuntu-os-cloud \
        --licenses https://www.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx

echo "Done."
sleep 2s

# Creating EVE-ng instance
#==========================================
clear
echo "-------------------------------"
echo "--> Creating EVE-ng instance."
echo "-------------------------------"
sleep 1s
gcloud compute instances create $INSTANCE_NAME \
--project=$PROJECT_ID \
--zone=$ZONE \
--machine-type=n2-highmem-4 \
--network-interface=network-tier=PREMIUM,subnet=$TRUST_NET_NAME \
--can-ip-forward \
--maintenance-policy=MIGRATE \
--provisioning-model=STANDARD \
--create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/$PROJECT_ID/global/images/nested-ubuntu-focal,mode=rw,size=50,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-ssd \
--no-shielded-secure-boot \
--shielded-vtpm \
--shielded-integrity-monitoring \
--reservation-affinity=any


EVE_MGMT_EXIP=$(gcloud compute instances describe $INSTANCE_NAME --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Done."
sleep 2s


ssh -o "StrictHostKeyChecking no" -i .ssh/id_rsa admin@$EVE_MGMT_EXIP "sudo -i && wget -O - https://www.eve-ng.net/focal/install-eve.sh | bash -i && apt update && apt upgrade && reboot"
