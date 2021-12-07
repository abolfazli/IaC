// Configure the Google Cloud provider
provider "google" {
  project     = "${var.gcp_project_id}"
  region      = "${var.region}"
}
