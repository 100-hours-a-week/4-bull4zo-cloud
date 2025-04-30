resource "google_compute_network" "vpc_network" {
  name                    = "moa-dev-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "moa-dev-pub-sub"
  ip_cidr_range = "192.168.10.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  private_ip_google_access = false
}

resource "google_compute_firewall" "allow-internal" {
  name    = "moa-dev-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["192.168.0.0/16"]
}

resource "google_compute_firewall" "allow-ssh-http-https" {
  name    = "moa-dev-allow-ssh-http-https"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_route" "default_internet_route" {
  name                   = "moa-dev-default-internet-route"
  network                = google_compute_network.vpc_network.name
  dest_range             = "0.0.0.0/0"
  next_hop_gateway       = "default-internet-gateway"
  priority               = 1000
}
