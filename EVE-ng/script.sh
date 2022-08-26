# STILL IN TEST AND EDIT MODE!!!

#!/bin/bash

# Defining Evrironment Variables
#==========================================
clear
echo "-------------------------------------"
echo "--> Setting up environment variables."
echo "-------------------------------------"
PROJECT_ID=$(gcloud projects list --format="value(projectId)")

gcloud config set project $PROJECT_ID

ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1
SSH_KEY=$(cat .ssh/id_rsa.pub)

export REGION="us-central1"
export ZONE="us-central1-a"
export INSTANCE_NAME="pa-fw-01"

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

# Creating 4 firewall rules to allow all trafics
#==========================================
clear
echo "----------------------------"
echo "--> Creating Firewall rules."
echo "----------------------------"
sleep 1s
gcloud compute --project=amir-gcp5 firewall-rules create ingress-eve --direction=INGRESS --priority=1000 --network=trust --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
gcloud compute --project=amir-gcp5 firewall-rules create ingress-eve --direction=ENGRESS --priority=1000 --network=trust --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all


gcloud compute --project=$PROJECT_ID firewall-rules create allow-all-trust --direction=INGRESS --priority=1000 --network=$TRUST_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
clear
gcloud compute --project=$PROJECT_ID firewall-rules create allow-all-untrust --direction=INGRESS --priority=1000 --network=$UNTRUST_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
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

# Creating firewall instance
#==========================================
clear
echo "-------------------------------"
echo "--> Creating firewall instance."
echo "-------------------------------"
sleep 1s
gcloud compute instances create eve-ng \
--project=amir-gcp5 \
--zone=us-central1-a \
--machine-type=n2-highmem-4 \
--network-interface=network-tier=PREMIUM,subnet=management \
--can-ip-forward \
--maintenance-policy=MIGRATE \
--provisioning-model=STANDARD \
--create-disk=auto-delete=yes,boot=yes,device-name=eve-ng,image=projects/amir-gcp5/global/images/nested-ubuntu-focal,mode=rw,size=50,type=projects/amir-gcp5/zones/us-central1-a/diskTypes/pd-ssd \
--no-shielded-secure-boot \
--shielded-vtpm \
--shielded-integrity-monitoring \
--reservation-affinity=any


FIREWALL_MGMT_EXIP=$(gcloud compute instances describe $INSTANCE_NAME --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Done."
sleep 2s

# Creating system routes
#==========================================
clear
echo "---------------------------"
echo "--> Creating system routes."
echo "---------------------------"
sleep 1s
gcloud beta compute routes create trust-to-untrust --project=$PROJECT_ID --network=$TRUST_NET_NAME --priority=1000 --destination-range=$UNTRUST_NET_RNG --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
gcloud beta compute routes create trust-ro-dmz --project=$PROJECT_ID --network=$TRUST_NET_NAME --priority=1000 --destination-range=$DMZ_NET_RNG --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
gcloud beta compute routes create trust-to-internet --project=$PROJECT_ID --network=$TRUST_NET_NAME --priority=100 --destination-range=0.0.0.0/0 --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
clear
gcloud beta compute routes create dmz-to-untrust --project=$PROJECT_ID --network=$DMZ_NET_NAME --priority=1000 --destination-range=$UNTRUST_NET_RNG --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
gcloud beta compute routes create dmz-ro-trust --project=$PROJECT_ID --network=$DMZ_NET_NAME --priority=1000 --destination-range=$TRUST_NET_RNG --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
gcloud beta compute routes create dmz-to-internet --project=$PROJECT_ID --network=$DMZ_NET_NAME --priority=100 --destination-range=0.0.0.0/0 --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
clear
gcloud beta compute routes create untrust-ro-trust --project=$PROJECT_ID --network=$UNTRUST_NET_NAME --priority=1000 --destination-range=$TRUST_NET_RNG --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
gcloud beta compute routes create untrust-ro-dmz --project=$PROJECT_ID --network=$UNTRUST_NET_NAME --priority=1000 --destination-range=$DMZ_NET_RNG --next-hop-instance=$INSTANCE_NAME --next-hop-instance-zone=$ZONE
echo "Done."
sleep 2s

# PaloAlto Firewall bootup
#==========================================
clear
echo "Waiting for Firewall to boots up..."
while true;
do
  ping -c1 $FIREWALL_MGMT_EXIP >/dev/null 2>&1
  if [ $? -eq 0 ]
  then
    sleep 2m
    exit 0
  fi
done


ssh -o "StrictHostKeyChecking no" -i .ssh/id_rsa admin@$FIREWALL_MGMT_EXIP
