#!/bin/bash

# What are the requirements to create a test LAB:
# 1. Createing a GCP Project that contains all your configs.
# 2. Create 4 VPCs for each firewall interface: management, trust, untrust, dmz and assign a subnet range for them
# 3. GCP has it's own firewall that we are going to allow all traffic in that to reduce complexity.
# 4. We should define Region and Zone that all objects should be created
# 5. We should define static routes for inter-vpc and internet communication to go through our firewall
# 6. We need a SSH Key to be created and imported to our Palo Alto firewall
#gcloud compute images list --project paloaltonetworksgcp-public --no-standard-images --uri | grep vmseries-flex-bundle2-11

#==============================================================================================
#|                                         WARNING                                             |
#==============================================================================================
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
clear
read -p "Do you know that you should be running this script in a test network in your own private GCP account rather than in the production network? (Enter 'yes' to continue): " i_accept

i_accept=$(echo "$i_accept" | tr '[:upper:]' '[:lower:]')

if [[ "$i_accept" != "yes" ]]; then
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
gcloud projects list
read -p "Enter your Project ID: " PROJECT_ID
gcloud config set project $PROJECT_ID
echo "Default region is: $REGION"
echo "Default zone is:   $ZONE"

read -p "Do you want to change the default region and zone? (y/n): " change_defaults

if [[ "$change_defaults" == "y" || $change_defaults == "yes" || $change_defaults == "Y" || $change_defaults == "y" ]]; then
  read -p "Enter the new default region: " new_region
  REGION="$new_region"
  read -p "Enter the new default zone: " new_zone
  ZONE="$new_zone"
fi
#------------------------------------------------------------------------------------

read -p "Enter new firewall name: " INSTANCE_NAME

PROJECT_ID=$(echo "$PROJECT_ID" | tr '[:upper:]' '[:lower:]')
REGION=$(echo "$REGION" | tr '[:upper:]' '[:lower:]')
ZONE=$(echo "$ZONE" | tr '[:upper:]' '[:lower:]')
INSTANCE_NAME=$(echo "$INSTANCE_NAME" | tr '[:upper:]' '[:lower:]')


## Ask for SSH Key 
#------------------------------------------------------------------------------------
read -p "Do you want to generate a new SSH key? (yes/No): " need_sshkey

if [[ $need_sshkey == "Yes" || $need_sshkey == "yes" || $need_sshkey == "Y" || $need_sshkey == "y" ]]; then
  ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1
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
# Define the network configurations
NETWORKS=(
    "mgmt 10.0.0.0/16"
    "trust 10.1.0.0/16"
    "untrust 10.2.0.0/16"
    "dmz 10.3.0.0/16"
)

# Create networks using a loop
for NETWORK in "${NETWORKS[@]}"; do
    NETWORK_NAME=$(echo "$NETWORK" | cut -d' ' -f1)
    NETWORK_RANGE=$(echo "$NETWORK" | cut -d' ' -f2)

    gcloud compute networks create "$NETWORK_NAME" \
        --project="$PROJECT_ID" \
        --subnet-mode=auto \
        --bgp-routing-mode=regional

    gcloud compute networks subnets create "$NETWORK_NAME-subnet" \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --network="$NETWORK_NAME" \
        --range="$NETWORK_RANGE"
done

# Define the subnet configurations
SUBNETS=(
    "management management-subnet 10.0.0.0/24"
    "trust trust-subnet1 10.1.1.0/24"
    "trust trust-subnet2 10.1.2.0/24"
    "trust trust-subnet3 10.1.3.0/24"
    "untrust untrust-subnet1 10.2.1.0/24"
    "untrust untrust-subnet2 10.2.2.0/24"
    "dmz dmz-subnet1 10.3.1.0/24"
    "dmz dmz-subnet2 10.3.2.0/24"
)

# Create subnets using a loop
for SUBNET in "${SUBNETS[@]}"; do
    NETWORK=$(echo "$SUBNET" | cut -d' ' -f1)
    SUBNET_NAME=$(echo "$SUBNET" | cut -d' ' -f2)
    SUBNET_RANGE=$(echo "$SUBNET" | cut -d' ' -f3)

    gcloud compute networks subnets create "$SUBNET_NAME" \
       --project="$PROJECT_ID" \
       --region="$REGION" \
       --network="$NETWORK" \
       --range="$SUBNET_RANGE"
    gcloud compute routes create "$vpc_name-subnet1-inter-vpc-route" \
       --project "$PROJECT_ID" \
       --network "$vpc_name" \
       --destination-range "10.0.0.0/8" \
       --next-hop-instance "$INSTANCE_NAME" \
       --next-hop-instance-zone "$REGION"

    gcloud compute routes create "default-$vpc_name-subnet1-internet-route" \
       --project "$PROJECT_ID" \
       --network "$vpc_name" \
       --destination-range "0.0.0.0/0" \
       --next-hop-instance "$INSTANCE_NAME" \
       --next-hop-instance-zone "$REGION"

    gcloud compute  --project=$PROJECT_ID firewall-rules create "$vpc_name-allow-all" \
       --direction=INGRESS \
       --priority=1000 \
       --network="$vpc_name" \
       --action=ALLOW \
       --rules=all \
       --source-ranges=0.0.0.0/0 \
       --enable-logging \
       --logging-metadata=exclude-all
done


####

create_vpc() {
  local vpc_name=$1
  local subnet_range=$2

  clear

  gcloud compute networks create "$vpc_name" --project "$PROJECT_ID" --subnet-mode custom --bgp-routing-mode global

  gcloud compute networks subnets create "$vpc_name-subnet1" \
    --project "$PROJECT_ID" \
    --range "$subnet_range" \
    --network "$vpc_name" \
    --region "$REGION"


}

create_vpc "management" "10.0.1.0/24"
create_vpc "trust" "10.1.1.0/24"
create_vpc "untrust" "10.2.1.0/24"
create_vpc "dmz" "10.3.1.0/24"
####

gcloud services enable compute.googleapis.com deploymentmanager.googleapis.com runtimeconfig.googleapis.com

gcloud compute instances create $INSTANCE_NAME \
        --description="Palo Alto Firewall" \
        --zone=$ZONE \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle2-1101,mode=rw,size=60 \
        --maintenance-policy=TERMINATE \
        --machine-type=n2-standard-8 \
        --network-interface=network-tier=PREMIUM,network=management,subnet=management-subnet \
        --network-interface=network-tier=PREMIUM,network=untrust,subnet=untrust-subnet1 \
        --network-interface=network-tier=PREMIUM,network=untrust,subnet=untrust-subnet2 \
        --network-interface=network-tier=PREMIUM,network=trust,subnet=trust-subnet1,no-address \
        --network-interface=network-tier=PREMIUM,network=trust,subnet=trust-subnet2,no-address \
        --network-interface=network-tier=PREMIUM,network=trust,subnet=trust-subnet3,no-address \
        --network-interface=network-tier=PREMIUM,network=dmz,subnet=dmz-subnet1,no-address \
        --network-interface=network-tier=PREMIUM,network=dmz,subnet=dmz-subnet2,no-address \
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