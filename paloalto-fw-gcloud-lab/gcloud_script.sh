#!/bin/bash
echo "Hi, Please Enter Your Name"
read you_name
echo "$you_name Please enter admin password for firewall"
read you_password
echo "Great, Thank you $you_name. Let's start..."
sleep 2s

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

export MGMT_NET_NAME="management"
export TRUST_NET_NAME="trust"
export UNTRUST_NET_NAME="untrust"
export DMZ_NET_NAME="dmz"

export MGMT_NET_RNG="192.168.0.0/24"
export TRUST_NET_RNG="192.168.1.0/24"
export UNTRUST_NET_RNG="192.168.2.0/24"
export DMZ_NET_RNG="192.168.3.0/24"
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
gcloud compute networks create $MGMT_NET_NAME --project=$PROJECT_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional && gcloud compute networks subnets create $MGMT_NET_NAME --project=$PROJECT_ID --range=$MGMT_NET_RNG --network=$MGMT_NET_NAME --region=$REGION
clear
gcloud compute networks create $TRUST_NET_NAME --project=$PROJECT_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional && gcloud compute networks subnets create $TRUST_NET_NAME --project=$PROJECT_ID --range=$TRUST_NET_RNG --network=$TRUST_NET_NAME --region=$REGION
clear
gcloud compute networks create $UNTRUST_NET_NAME --project=$PROJECT_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional && gcloud compute networks subnets create $UNTRUST_NET_NAME --project=$PROJECT_ID --range=$UNTRUST_NET_RNG --network=$UNTRUST_NET_NAME --region=$REGION
clear
gcloud compute networks create $DMZ_NET_NAME --project=$PROJECT_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional && gcloud compute networks subnets create $DMZ_NET_NAME --project=$PROJECT_ID --range=$DMZ_NET_RNG --network=$DMZ_NET_NAME --region=$REGION
echo "Done."
sleep 2s

# Creating 4 firewall rules to allow all trafics
#==========================================
clear
echo "----------------------------"
echo "--> Creating Firewall rules."
echo "----------------------------"
sleep 1s
gcloud compute --project=$PROJECT_ID firewall-rules create allow-all-mgmt --direction=INGRESS --priority=1000 --network=$MGMT_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
clear
gcloud compute --project=$PROJECT_ID firewall-rules create allow-all-trust --direction=INGRESS --priority=1000 --network=$TRUST_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
clear
gcloud compute --project=$PROJECT_ID firewall-rules create allow-all-untrust --direction=INGRESS --priority=1000 --network=$UNTRUST_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
clear
gcloud compute --project=$PROJECT_ID firewall-rules create allow-all-dmz --direction=INGRESS --priority=1000 --network=$DMZ_NET_NAME --action=ALLOW --rules=all --source-ranges=0.0.0.0/0 --enable-logging --logging-metadata=exclude-all
echo "Done."
sleep 2s

# Creating PC instance in Trust and DMZ
#==========================================
clear
echo "-----------------------------------"
echo "--> Creating PC Instances instance."
echo "-----------------------------------"
sleep 1s
gcloud compute instances create trust-pc-1 \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=f1-micro \
        --network-interface=subnet=$TRUST_NET_NAME,no-address

gcloud compute instances create dmz-pc-1 \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=f1-micro \
        --network-interface=subnet=$DMZ_NET_NAME,no-address

echo "Done."
sleep 2s

# Creating firewall instance
#==========================================
clear
echo "-------------------------------"
echo "--> Creating firewall instance."
echo "-------------------------------"
sleep 1s
gcloud compute instances create $INSTANCE_NAME \
        --description="Palo Alto Firewall" \
        --zone=$ZONE \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle2-1013,mode=rw,size=60 \
        --maintenance-policy=TERMINATE \
        --machine-type=n1-standard-4 \
        --network-interface=network-tier=PREMIUM,network=$MGMT_NET_NAME,subnet=$MGMT_NET_NAME \
        --network-interface=network-tier=PREMIUM,network=$UNTRUST_NET_NAME,subnet=$UNTRUST_NET_NAME \
        --network-interface=network-tier=PREMIUM,network=$TRUST_NET_NAME,subnet=$TRUST_NET_NAME,no-address \
        --network-interface=network-tier=PREMIUM,network=$DMZ_NET_NAME,subnet=$DMZ_NET_NAME,no-address \
        --metadata=ssh-keys="$SSH_KEY" \
        --boot-disk-auto-delete \
        --tags=firewall \
        --labels=type=firewall 

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

echo "Firewall successfully boots up :-)"

ssh -o "StrictHostKeyChecking no" -i .ssh/id_rsa admin@$FIREWALL_MGMT_EXIP

# PaloAlto Firewall basic configuration
#==========================================
clear
echo "------------------------------"
echo "--> Basic config for firewall."
echo "------------------------------"
sleep 1s

configure
set mgt-config users admin
AAAaaa.123
AAAaaa.123

set deviceconfig system hostname pa-fw-01

set network interface ethernet ethernet1/1 layer3 dhcp-client 
set network interface ethernet ethernet1/1 layer3 interface-management-profile allow-ping
set network interface ethernet ethernet1/2 layer3 dhcp-client 
set network interface ethernet ethernet1/2 layer3 interface-management-profile allow-ping
set network interface ethernet ethernet1/3 layer3 dhcp-client 
set network interface ethernet ethernet1/3 layer3 interface-management-profile allow-ping
set network profiles interface-management-profile allow-ping ping yes

set network virtual-router default interface [ ethernet1/1 ethernet1/2 ethernet1/3 ]
set network virtual-router default routing-table ip static-route default-route nexthop ip-address 192.168.1.1
set network virtual-router default routing-table ip static-route default-route interface ethernet1/1
set network virtual-router default routing-table ip static-route default-route metric 10
set network virtual-router default routing-table ip static-route default-route destination 0.0.0.0/0
set network virtual-router default routing-table ip static-route default-route route-table unicast 

set zone untrust network layer3 ethernet1/1
set zone trust network layer3 ethernet1/2
set zone dmz network layer3 ethernet1/3
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

set import network interface [ ethernet1/1 ethernet1/2 ethernet1/3 ]

commit
