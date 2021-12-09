/*
 "--------------------------------------------------------------------"
 "---------------------> Enable GCP API Services <--------------------"
 "--------------------------------------------------------------------"


resource "google_project_service" "api_services" {
  count   = length(var.gcp_api_list)
  project = "${var.gcp_project_id}"
  service = var.gcp_api_list[count.index]

  disable_dependent_services = true
}
*/

/*
 "--------------------------------------------------------------------"
 "---------------------> Creating VPC networks <----------------------"
 "--------------------------------------------------------------------"
*/

// Adding VPC Networks to Project  MANAGEMENT
resource "google_compute_subnetwork" "management-sub-01" {
  name          = "${var.management_net}-sub-01"
  ip_cidr_range = "${var.management_range}"
  network       = "${google_compute_network.management.self_link}"
  region        = "${var.region}"
}

resource "google_compute_network" "management" {
  name                    = "${var.management_net}"
  auto_create_subnetworks = "false"
  mtu                     = "1460"
}

// Adding VPC Networks to Project  UNTRUST
resource "google_compute_subnetwork" "untrust-sub-01" {
  name          = "${var.untrust_net}-sub-01"
  ip_cidr_range = "${var.untrust_range}"
  network       = "${google_compute_network.untrust.self_link}"
  region        = "${var.region}"
}

resource "google_compute_network" "untrust" {
  name                    = "${var.untrust_net}"
  auto_create_subnetworks = "false"
  mtu                     = "1460"
}

// Adding VPC Networks to Project  TRUST
resource "google_compute_subnetwork" "trust-sub-01" {
  name          = "${var.trust_net}-sub-01"
  ip_cidr_range = "${var.trust_range}"
  network       = "${google_compute_network.trust.self_link}"
  region        = "${var.region}"
}

resource "google_compute_network" "trust" {
  name                    = "${var.trust_net}"
  auto_create_subnetworks = "false"
  mtu                     = "1460"
}

// Adding VPC Networks to Project  DMZ
resource "google_compute_subnetwork" "dmz-sub-01" {
  name          = "${var.dmz_net}-sub-01"
  ip_cidr_range = "${var.dmz_range}"
  network       = "${google_compute_network.dmz.self_link}"
  region        = "${var.region}"
}

resource "google_compute_network" "dmz" {
  name                    = "${var.dmz_net}"
  auto_create_subnetworks = "false"
  mtu                     = "1460"
}

/*
 "--------------------------------------------------------------------"
 "---------------------> Creating system routes <---------------------"
 "--------------------------------------------------------------------"
*/

// Adding GCP Route to TRUST Interface
resource "google_compute_route" "trust-to-internet" {
  name                   = "${var.trust_net}-to-internet"
  dest_range             = "0.0.0.0/0"
  network                = "${google_compute_network.trust.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.trust]
}

resource "google_compute_route" "trust-to-untrust" {
  name                   = "${var.trust_net}-to-${var.untrust_net}"
  dest_range             = "${var.untrust_range}"
  network                = "${google_compute_network.trust.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.trust,google_compute_network.untrust]
}

resource "google_compute_route" "trust-ro-dmz" {
  name                   = "${var.trust_net}-to-${var.dmz_net}"
  dest_range             = "${var.dmz_range}"
  network                = "${google_compute_network.trust.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.trust,google_compute_network.dmz]
}

// Adding GCP Route to DMZ Interface
resource "google_compute_route" "dmz-to-internet" {
  name                   = "${var.dmz_net}-to-internet"
  dest_range             = "0.0.0.0/0"
  network                = "${google_compute_network.dmz.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.dmz]
}

resource "google_compute_route" "dmz-to-trust" {
  name                   = "${var.dmz_net}-to-${var.trust_net}"
  dest_range             = "${var.trust_range}"
  network                = "${google_compute_network.dmz.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.trust,google_compute_network.dmz]
}

resource "google_compute_route" "dmz-to-untrust" {
  name                   = "${var.dmz_net}-to-${var.untrust_net}"
  dest_range             = "${var.untrust_range}"
  network                = "${google_compute_network.dmz.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.untrust,google_compute_network.dmz]
}

resource "google_compute_route" "untrust-to-trust" {
  name                   = "${var.untrust_net}-to-${var.trust_net}"
  dest_range             = "${var.trust_range}"
  network                = "${google_compute_network.untrust.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.trust,google_compute_network.untrust]
}

resource "google_compute_route" "untrust-to-dmz" {
  name                   = "${var.untrust_net}-to-${var.dmz_net}"
  dest_range             = "${var.dmz_range}"
  network                = "${google_compute_network.untrust.self_link}"
  next_hop_instance      = "${var.firewall_name}"
  next_hop_instance_zone = "${var.zone}"
  priority               = 100

  depends_on = [google_compute_instance.firewall,google_compute_network.untrust,google_compute_network.dmz]
}

/*
 "--------------------------------------------------------------------"
 "---------------------> Creating Firewall Rules <--------------------"
 "--------------------------------------------------------------------"
*/

// Adding GCP Firewall Rules for MANGEMENT
resource "google_compute_firewall" "allow-mgmt-icmp-ssh-https" {
  name    = "allow-mgmt-icmp-ssh-https"
  network = "${google_compute_network.management.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["443", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

// Adding GCP Firewall Rules for UNTRUST INBOUND ALL
resource "google_compute_firewall" "allow-all-untrust" {
  name    = "allow-all-${var.untrust_net}"
  network = "${google_compute_network.untrust.self_link}"

  allow {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

// Adding GCP Firewall Rules for TRUST INBOUND ALL
resource "google_compute_firewall" "allow-all-trust" {
  name    = "allow-all-${var.trust_net}"
  network = "${google_compute_network.trust.self_link}"

  allow {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

// Adding GCP Firewall Rules for DMZ INBOUND ALL
resource "google_compute_firewall" "allow-all-dmz" {
  name    = "allow-all-${var.dmz_net}"
  network = "${google_compute_network.dmz.self_link}"

  allow {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

/*
 "--------------------------------------------------------------------"
 "----------------------> Creating Firewall VM <----------------------"
 "--------------------------------------------------------------------"
*/

data "google_client_openid_userinfo" "me" {
}

resource "google_os_login_ssh_public_key" "cache" {
  user =  data.google_client_openid_userinfo.me.email
  key = file("~/.ssh/id_rsa.pub")
  project     = "${var.gcp_project_id}"
}

resource "google_compute_instance" "firewall" {
  name                      = "${var.firewall_name}"
  machine_type              = "${var.firewall_machine_type}"
  zone                      = "${var.zone}"
  min_cpu_platform          = "${var.firewall_machine_cpu}"
  can_ip_forward            = true
  allow_stopping_for_update = true
  count                     = 1
  
  //depends_on = [google_project_service.api_services]

  metadata = {
    serial-port-enable                   = true
    ssh-keys = "admin:${file("~/.ssh/id_rsa.pub")}"
  }

  service_account {
    scopes = "${var.firewall_scopes}"
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.management-sub-01.self_link}"
    access_config {}
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.untrust-sub-01.self_link}"
    access_config {}
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.trust-sub-01.self_link}"
  }
 
   network_interface {
    subnetwork = "${google_compute_subnetwork.dmz-sub-01.self_link}"
  }

  boot_disk {
    initialize_params {
      image = "${var.firewall_image}"
    }
  }
}

/*
 "--------------------------------------------------------------------"
 "-----------------------> Creating TRUST PC <------------------------"
 "--------------------------------------------------------------------"
*/

resource "google_compute_instance" "trust-pc-1" {
  name         = "${var.trust_pc_name}"
  machine_type = "${var.pc_machine_type}"
  zone         = "${var.zone}"
  tags = ["trust"]

  //depends_on = [google_project_service.api_services]

  boot_disk {
    initialize_params {
      image = "${var.pc_image}"
    }
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.trust-sub-01.self_link}" 
  }
}

/*
 "--------------------------------------------------------------------"
 "-----------------------> Creating DMZ PC <--------------------------"
 "--------------------------------------------------------------------"
*/

resource "google_compute_instance" "dmz-pc-1" {
  name         = "${var.dmz_pc_name}"
  machine_type = "${var.pc_machine_type}"
  zone         = "${var.zone}"
  tags = ["dmz"]

  //depends_on = [google_project_service.api_services]

  boot_disk {
    initialize_params {
      image = "${var.pc_image}"
    }
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.dmz-sub-01.self_link}"
  }
}

/*
resource "time_sleep" "wait_for_firewall_bootup" {
  create_duration = "180s"
}
*/
