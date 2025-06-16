provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone 
}

terraform {
  backend "gcs" {
    bucket  = "bigbucketofcrabs99" #Manually provisioned this backend
    prefix  = "terraform/state"
  }
}

resource "google_compute_network" "default" {
  name                    = "example-network"
  auto_create_subnetworks = false
  enable_ula_internal_ipv6 = true
}

resource "google_compute_subnetwork" "default" {
  name          = "example-subnetwork"
  ip_cidr_range = "10.0.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.default.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/22"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.4.0/22"
  }
}

resource "google_container_cluster" "default" {
  name     = "testbed"
  location = "us-central1-a"
  initial_node_count = 2
  enable_l4_ilb_subsetting = true
  deletion_protection = false

  network    = google_compute_network.default.id
  subnetwork = google_compute_subnetwork.default.id

  ip_allocation_policy {
    stack_type                    = "IPV4"
    services_secondary_range_name = google_compute_subnetwork.default.secondary_ip_range[0].range_name
    cluster_secondary_range_name  = google_compute_subnetwork.default.secondary_ip_range[1].range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.16/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_authorized_networks_config {
  cidr_blocks {
    cidr_block   = "35.235.240.0/20"
    display_name = "cloud-shell"
  }
  cidr_blocks {
   cidr_block   = "72.198.103.130/32"
   display_name = "home"
 }
  cidr_blocks {
    cidr_block = "0.0.0.0/0"
    display_name = "Allow All Test"
  }
}
}

resource "google_compute_router" "router" {
  name    = "gke-nat-router"
  region  = var.region
  network = google_compute_network.default.id
}

resource "google_compute_firewall" "gke-lb-healthcheck" {
  name    = "allow-lb-healthcheck"
  network = google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["gke-node"]
}

resource "google_compute_network" "vm_network" {
  name                    = "vm-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vm_subnet" {
  name          = "vm-subnet"
  ip_cidr_range = "10.20.0.0/16"
  region        = var.region
  network       = google_compute_network.vm_network.id
}

resource "google_compute_network_peering" "gke_to_vm" {
  name         = "gke-to-vm"
  network      = google_compute_network.default.id
  peer_network = google_compute_network.vm_network.id
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "vm_to_gke" {
  name         = "vm-to-gke"
  network      = google_compute_network.vm_network.id
  peer_network = google_compute_network.default.id
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_service_account" "mongo_vm_sa" {
  account_id   = "mongo-vm-sa"
  display_name = "Mongo VM Service Account"
}

resource "google_service_account_iam_member" "allow_infra_to_impersonate" {
  service_account_id = google_service_account.mongo_vm_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:infra-provision@${var.project_id}.iam.gserviceaccount.com"
}


resource "google_project_iam_member" "allow_vm_service_account_full_access" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.mongo_vm_sa.email}"
}

resource "google_compute_instance" "vm_instance" {
  name         = "test-vm"
  machine_type = "e2-small"
  zone         = var.zone
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/rhel-cloud/global/images/rhel-8-v20231010"
    }
  }

  network_interface {
    network    = google_compute_network.vm_network.id
    subnetwork = google_compute_subnetwork.vm_subnet.id
    access_config {} 
  }

  service_account {
    email  = google_service_account.mongo_vm_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["allow-from-gke", "allow-public-ssh"]

}

resource "google_compute_firewall" "allow_gke_to_vm" {
  name    = "allow-gke-to-vm"
  network = google_compute_network.vm_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "27017"]
  }

  allow {
    protocol = "icmp" 
  }

  source_ranges = ["10.0.0.0/16", "192.168.4.0/22"]
  target_tags   = ["allow-from-gke"]
}

resource "google_compute_firewall" "allow_public_ssh" {
  name    = "allow-public-ssh"
  network = google_compute_network.vm_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-public-ssh"]
}

resource "google_storage_bucket" "mongo_backup_bucket" {
  name          = "mongo-backup-${var.project_id}"
  location      = "US"
  force_destroy = true  
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.mongo_backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "mongo_vm_write" {
  bucket = google_storage_bucket.mongo_backup_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.mongo_vm_sa.email}"
}
