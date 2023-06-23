#!/bin/bash

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

SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
SSH_KEY=("admin:$SSH_KEY")
echo "SSH Public Key is: "$SSH_KEY
echo " "
#------------------------------------------------------------------------------------
# create a VPC
#------------------------------------------------------------------------------------

# Define the subnet configurations
SUBNETS=(
    "management management-subnet 10.0.0.0/24"
    "untrust untrust-subnet1 10.2.1.0/24"
    "untrust untrust-subnet2 10.2.2.0/24"
    "trust trust-subnet 10.1.1.0/24"
    "dmz dmz-subnet 10.3.1.0/24"
)

# Create subnets using a loop
for SUBNET in "${SUBNETS[@]}"; do
    VPC_SUBNET_NAME=$(echo "$SUBNET" | cut -d' ' -f2)
    VPC_SUBNET_RANGE=$(echo "$SUBNET" | cut -d' ' -f3)
    clear
    echo "===================================================="
    echo -e "Creating Resources for $VPC_SUBNET_NAME network"
    echo "===================================================="

    gcloud compute networks create "$VPC_SUBNET_NAME" --project "$PROJECT_ID" --subnet-mode custom --bgp-routing-mode global

    gcloud compute networks subnets create "$VPC_SUBNET_NAME" \
       --project="$PROJECT_ID" \
       --region="$REGION" \
       --network="$VPC_SUBNET_NAME" \
       --range="$VPC_SUBNET_RANGE"

    gcloud compute routes create "$VPC_SUBNET_NAME-inter-vpc-route" \
       --project "$PROJECT_ID" \
       --network "$VPC_SUBNET_NAME" \
       --destination-range "10.0.0.0/8" \
       --next-hop-instance "$INSTANCE_NAME" \
       --next-hop-instance-zone "$ZONE"

    gcloud compute routes create "default-$VPC_SUBNET_NAME-internet-route" \
       --project "$PROJECT_ID" \
       --network "$VPC_SUBNET_NAME" \
       --destination-range "0.0.0.0/0" \
       --next-hop-instance "$INSTANCE_NAME" \
       --next-hop-instance-zone "$ZONE"
    
    gcloud compute  --project=$PROJECT_ID firewall-rules create "$VPC_SUBNET_NAME-allow-all" \
       --direction=INGRESS \
       --priority=1000 \
       --network="$VPC_SUBNET_NAME" \
       --action=ALLOW \
       --rules=all \
       --source-ranges=0.0.0.0/0 \
       --enable-logging \
       --logging-metadata=exclude-all
done
gcloud compute routes delete default-management-subnet-internet-route --project "$PROJECT_ID" 
gcloud compute routes delete default-untrust-subnet1-internet-route --project "$PROJECT_ID" 
gcloud compute routes delete default-untrust-subnet2-internet-route --project "$PROJECT_ID" 
clear
gcloud services enable compute.googleapis.com deploymentmanager.googleapis.com runtimeconfig.googleapis.com
#gcloud compute images list --project paloaltonetworksgcp-public --no-standard-images --uri | grep vmseries-flex-bundle2-11
gcloud compute instances create $INSTANCE_NAME \
        --description="Palo Alto Firewall" \
        --zone=$ZONE \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle2-1101,mode=rw,size=60 \
        --maintenance-policy=TERMINATE \
        --machine-type=n2-standard-8 \
        --network-interface=network-tier=PREMIUM,network=management-subnet,subnet=management-subnet \
        --network-interface=network-tier=PREMIUM,network=untrust-subnet1,subnet=untrust-subnet1 \
        --network-interface=network-tier=PREMIUM,network=untrust-subnet2,subnet=untrust-subnet2 \
        --network-interface=network-tier=PREMIUM,network=trust-subnet,subnet=trust-subnet,no-address \
        --network-interface=network-tier=PREMIUM,network=dmz-subnet,subnet=dmz-subnet,no-address \
        --metadata=ssh-keys="$SSH_KEY" \
        --boot-disk-auto-delete \
        --tags=firewall \
        --labels=type=firewall \
        --can-ip-forward

FIREWALL_MGMT_EXIP=$(gcloud compute instances describe $INSTANCE_NAME --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

while ! ping -c1 $FIREWALL_MGMT_EXIP &> /dev/null; do
  echo -e "$FIREWALL_MGMT_EXIP is not reachable"
  sleep 20
done
clear
echo -e "\n\n$FIREWALL_MGMT_EXIP is now reachable . we should wait 10 minutes to complete booting process\n"
sleep 500

echo -e "When firewall boots up use the following commands to set password:\n\n# configure\n# set mgt-config users admin password\n\n"

ssh -o "HostKeyAlgorithms=+ssh-rsa" -o "StrictHostKeyChecking no" -i ~/.ssh/id_rsa admin@$FIREWALL_MGMT_EXIP

#API_KEY="API KEY"
#X-PAN-KEY="X PAN KEY"

: '
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"hostname": "pa-fw-01"}' https://$FIREWALL_MGMT_EXIP/api/?type=op&cmd=<request><system><hostname></hostname></system></request>

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"type": "layer3", "dhcp": "client"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/network/interface/ethernet/entry[@name='ethernet1/1']/layer3
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"interface-management-profile": "allow-ping"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/network/interface/ethernet/entry[@name='ethernet1/1']/layer3
...

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"ping": "yes"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/shared/network/profiles/interface-management-profile/entry[@name='allow-ping']

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"interface": ["ethernet1/1", "ethernet1/2", "ethernet1/3"]}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/network/virtual-router/entry[@name='default']/interface

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"ip": {"static-route": [{"name": "default-route", "destination": "0.0.0.0/0", "nexthop": {"ip-address": "192.168.1.1"}, "interface": "ethernet1/1", "route-table": "unicast", "metric": "10"}]}}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/network/virtual-router/entry[@name='default']/routing-table/ip

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"network": "layer3", "interface": "ethernet1/1"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/zone/entry[@name='untrust']
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"network": "layer3", "interface": "ethernet1/2"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/zone/entry[@name='trust']
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"network": "layer3", "interface": "ethernet1/3"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/zone/entry[@name='dmz']

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"color": "color22"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/tag/entry[@name='trust']
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"color": "color1"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/tag/entry[@name='untrust']
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"color": "color21"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/tag/entry[@name='dmz']

curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"to": ["dmz", "untrust"], "from": "trust", "action": "allow"}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/rulebase/security/rules/entry[@name='trust-to-other-permit']
...
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"to": "untrust", "from": ["dmz", "trust"], "source-translation": {"dynamic-ip-and-port": {"interface-address": "interface ethernet1/1"}}}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/rulebase/nat/rules/entry[@name='internet-access']
curl -X POST -H "$X-PAN-KEY: $API_KEY" -d '{"interface": ["ethernet1/1", "ethernet1/2", "ethernet1/3"]}' https://$FIREWALL_MGMT_EXIP/api/?type=config&action=set&xpath=/config/devices/entry[@name='localhost.localdomain']/network/interface/import
curl -X POST -H "$X-PAN-KEY: $API_KEY" https://$FIREWALL_MGMT_EXIP/api/?type=commit&cmd=<commit></commit>
'


: '
set deviceconfig system hostname fw-01
set network profiles interface-management-profile allow-ping ping yes
set network interface ethernet ethernet1/1 layer3 dhcp-client 
set network interface ethernet ethernet1/1 layer3 interface-management-profile allow-ping
set network interface ethernet ethernet1/2 layer3 dhcp-client 
set network interface ethernet ethernet1/2 layer3 interface-management-profile allow-ping
set network interface ethernet ethernet1/3 layer3 dhcp-client 
set network interface ethernet ethernet1/3 layer3 interface-management-profile allow-ping
set network interface ethernet ethernet1/4 layer3 dhcp-client 
set network interface ethernet ethernet1/4 layer3 interface-management-profile allow-ping

set network virtual-router default interface [ ethernet1/1 ethernet1/2 ethernet1/3 ethernet1/4 ]

set network virtual-router default routing-table ip static-route default-route-1 nexthop ip-address 10.2.1.1
set network virtual-router default routing-table ip static-route default-route-1 bfd profile None
set network virtual-router default routing-table ip static-route default-route-1 interface ethernet1/1
set network virtual-router default routing-table ip static-route default-route-1 metric 10
set network virtual-router default routing-table ip static-route default-route-1 destination 0.0.0.0/0
set network virtual-router default routing-table ip static-route default-route-1 route-table unicast

set network virtual-router default routing-table ip static-route default-route-2 nexthop ip-address 10.2.2.1
set network virtual-router default routing-table ip static-route default-route-2 bfd profile None
set network virtual-router default routing-table ip static-route default-route-2 interface ethernet1/2
set network virtual-router default routing-table ip static-route default-route-2 metric 20
set network virtual-router default routing-table ip static-route default-route-2 destination 0.0.0.0/0
set network virtual-router default routing-table ip static-route default-route-2 route-table unicast

set network virtual-router default interface [ ethernet1/1 ethernet1/2 ethernet1/3 ethernet1/4 ]

set zone untrust network layer3 ethernet1/1
set zone untrust network layer3 ethernet1/2
set zone trust network layer3 ethernet1/3
set zone dmz network layer3 ethernet1/4
set tag trust color color22
set tag untrust color color1
set tag dmz color color21

set rulebase security rules trust-to-other-permit to [ dmz untrust ]
set rulebase security rules trust-to-other-permit from trust
set rulebase security rules trust-to-other-permit source any
set rulebase security rules trust-to-other-permit destination any
set rulebase security rules trust-to-other-permit source-user any
set rulebase security rules trust-to-other-permit category any
set rulebase security rules trust-to-other-permit application any
set rulebase security rules trust-to-other-permit service application-default
set rulebase security rules trust-to-other-permit source-hip any
set rulebase security rules trust-to-other-permit destination-hip any
set rulebase security rules trust-to-other-permit action allow
set rulebase security rules dmz-to-other-permit to [ trust untrust ]
set rulebase security rules dmz-to-other-permit from dmz
set rulebase security rules dmz-to-other-permit source any
set rulebase security rules dmz-to-other-permit destination any
set rulebase security rules dmz-to-other-permit source-user any
set rulebase security rules dmz-to-other-permit category any
set rulebase security rules dmz-to-other-permit application any
set rulebase security rules dmz-to-other-permit service application-default
set rulebase security rules dmz-to-other-permit source-hip any
set rulebase security rules dmz-to-other-permit destination-hip any
set rulebase security rules dmz-to-other-permit action allow

set rulebase nat rules internet-access source-translation dynamic-ip-and-port interface-address interface ethernet1/1
set rulebase nat rules internet-access to untrust
set rulebase nat rules internet-access from [ dmz trust ]
set rulebase nat rules internet-access source any
set rulebase nat rules internet-access destination any
set rulebase nat rules internet-access service any

set import network interface [ ethernet1/1 ethernet1/2 ethernet1/3 ethernet1/4 ]

commit
'
