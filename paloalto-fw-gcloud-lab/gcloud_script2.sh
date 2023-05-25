#!/bin/bash

# What are the requirements to create a test LAB:
# 1. Createing a GCP Project that contains all your configs.
# 2. Create 4 VPCs for each firewall interface: management, trust, untrust, dmz and assign a subnet range for them
# 3. GCP has it's own firewall that we are going to allow all traffic in that to reduce complexity.
# 4. We should define Region and Zone that all objects should be created
# 5. We should define static routes for inter-vpc and internet communication to go through our firewall
# 6. We need a SSH Key to be created and imported to our Palo Alto firewall
#gcloud compute images list --project paloaltonetworksgcp-public --no-standard-images --uri | grep vmseries-flex-bundle2-11


## Warning
#------------------------------------------------------------------------------------

read -p "Do you want that you shouldn't run this script in Tangerine's network and this script only should be run in a test network in your own Prive GCP account? (Enter 'yes' to continue): " i_accept

if [[ "${i_accept,,}" != "yes" ]]; then
  echo "Script execution cancelled."
  exit 0
fi
#------------------------------------------------------------------------------------

gcloud auth login
clear

## Project ID, Region and Zone
#------------------------------------------------------------------------------------
REGION="us-east1"
ZONE="us-east1-b"

echo "Default region is: $REGION"
echo "Default zone is:   $ZONE"

read -p "Enter your Project ID: " PROJECT_ID
read -p "Do you want to change the default region and zone? (y/n): " change_defaults

if [ "$change_defaults" == "y" || $change_defaults == "yes" || $change_defaults == "Y" || $change_defaults == "y" ]]; then
  read -p "Enter the new default region: " new_region
  REGION="$new_region"
  read -p "Enter the new default zone: " new_zone
  ZONE="$new_zone"
fi
#------------------------------------------------------------------------------------

read -p "Enter new firewall name: " INSTANCE_NAME

## Ask for SSH Key 
#------------------------------------------------------------------------------------
read -p "Do you want to generate a new SSH key? (yes/No): " need_sshkey

if [[ $need_sshkey == "Yes" || $need_sshkey == "yes" || $need_sshkey == "Y" || $need_sshkey == "y" ]]; then
  #ssh-keygen -t rsa -b 4096 -C "abolfazli@outlook.com"
  #ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1
  echo "New SSH key generated."
elif [[ $need_sshkey == "No" || $need_sshkey == "no" || $need_sshkey == "N" || $need_sshkey == "n" || -z "$need_sshkey" ]]; then
  echo "No new SSH key generated."
else
  echo "Invalid input. Please type Yes or No."
fi

SSH_KEY=$(cat .ssh/id_rsa.pub)
SSH_KEY=("admin:$SSH_KEY")
echo "SSH Public Key is: "$SSH_KEY
echo " "
#------------------------------------------------------------------------------------

# create a VPC
#------------------------------------------------------------------------------------
create_vpc() {
  local vpc_name=$1
  local subnet_range=$2

  gcloud compute networks create "$vpc_name" --project "$PROJECT_ID" --subnet-mode custom --bgp-routing-mode global

  gcloud compute networks subnets create "$vpc_name-subnet" \
    --project "$PROJECT_ID" \
    --range "$subnet_range" \
    --network "$vpc_name" \
    --region "$REGION"
}

create_vpc "management" "192.168.0.0/24"
create_vpc "trust" "192.168.1.0/24"
create_vpc "untrust" "192.168.2.0/24"
create_vpc "dmz" "192.168.3.0/24"
#------------------------------------------------------------------------------------

# GCP Firewall Configurations: Allow all traffic in each VPC
#------------------------------------------------------------------------------------
for vpc_name in "management" "trust" "untrust" "dmz"; do
  gcloud compute firewall-rules create "$vpc_name-allow-all" \
    --project "$PROJECT_ID" \
    --network "$vpc_name" \
    --allow all \
    --source-ranges "$subnet_range"
done
#------------------------------------------------------------------------------------

# Create static route for inter-VPC traffic
#------------------------------------------------------------------------------------
gcloud compute routes create inter-vpc-route \
  --project "$PROJECT_ID" \
  --network "$vpc_name" \
  --destination-range "192.168.0.0/16" \
  --next-hop-instance "$INSTANCE_NAME" \
  --next-hop-instance-zone "$REGION"

gcloud compute routes create default-internet-route \
  --project "$PROJECT_ID" \
  --network "$vpc_name" \
  --destination-range "0.0.0.0/0" \
  --next-hop-instance "$INSTANCE_NAME" \
  --next-hop-instance-zone "$REGION"
#------------------------------------------------------------------------------------



gcloud services enable compute.googleapis.com deploymentmanager.googleapis.com runtimeconfig.googleapis.com

gcloud compute instances create $INSTANCE_NAME \
        --description="Palo Alto Firewall" \
        --zone=$ZONE \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle2-1101,mode=rw,size=60 \
        --maintenance-policy=TERMINATE \
        --machine-type=n1-standard-4 \
        --network-interface=network-tier=PREMIUM,network=$MGMT_NET_NAME,subnet=$MGMT_NET_NAME \
        --network-interface=network-tier=PREMIUM,network=$UNTRUST_NET_NAME,subnet=$UNTRUST_NET_NAME \
        --network-interface=network-tier=PREMIUM,network=$TRUST_NET_NAME,subnet=$TRUST_NET_NAME,no-address \
        --metadata=ssh-keys="$SSH_KEY" \
        --boot-disk-auto-delete \
        --tags=firewall \
        --labels=type=firewall 

FIREWALL_MGMT_EXIP=$(gcloud compute instances describe $INSTANCE_NAME --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

while ! ping -c1 $FIREWALL_MGMT_EXIP &> /dev/null; do
  echo "$FIREWALL_MGMT_EXIP is not reachable"
  sleep 5
done
echo "$FIREWALL_MGMT_EXIP is now reachable . we should wait some minutes to complete booting process"
sleep 500
echo "When firewall boots up use the following commands to set password:\n\n# configure\n# set mgt-config users admin password\n"

ssh -o "HostKeyAlgorithms=+ssh-rsa" -o "StrictHostKeyChecking no" -i .ssh/id_rsa admin@$FIREWALL_MGMT_EXIP
