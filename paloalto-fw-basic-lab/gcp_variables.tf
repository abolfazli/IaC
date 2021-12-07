// PROJECT Variables

variable "gcp_project_id" {}

variable "public_key" {}

variable "gcp_api_list" { 
    default = [ "compute.googleapis.com", "deploymentmanager.googleapis.com","runtimeconfig.googleapis.com"] 
    }

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-a"
}

// MANAGEMENT VPC
variable "management_net" {
  default = "management"
}

variable "management_range" {
  default = "192.168.0.0/24"
}

// UNTRUST VPC
variable "untrust_net" {
  default = "untrust"
}

variable "untrust_range" {
  default = "192.168.1.0/24"
}

// TRUST VPC
variable "trust_net" {
  default = "trust"
}

variable "trust_range" {
  default = "192.168.2.0/24"
}

//DMZ VPC
variable "dmz_net" {
  default = "dmz"
}

variable "dmz_range" {
  default = "192.168.3.0/24"
}

// VM-Series Firewall Variables 

variable "firewall_name" {
  default = "pa-firewall"
}

variable "firewall_image" {
  default = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle2-1013"
}

variable "firewall_machine_type" {
  default = "n1-standard-4"
}

variable "firewall_machine_cpu" {
  default = "Intel Skylake"
}

variable "firewall_scopes" {
  default = ["https://www.googleapis.com/auth/cloud.useraccounts.readonly",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
}

variable "trust_pc_name" {
  default = "trust-pc-1"
}

variable "dmz_pc_name" {
  default = "dmz-pc-1"
}

variable "pc_image" {
  default = "debian-cloud/debian-10"
}

variable "pc_machine_type" {
  default = "f1-micro"
}