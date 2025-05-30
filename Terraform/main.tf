# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "moa-main-vpc-${var.environment}"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "moa-pub-sub-${var.environment}-a"
  ip_cidr_range = "192.168.10.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Storage bucket for static frontend files
resource "google_storage_bucket" "static_website" {
  name          = "${var.project_id}-${var.environment}-frontend"
  location      = var.region
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

# Firewall rule for SSH and MySQL
resource "google_compute_firewall" "allow_ssh_mysql" {
  name    = "moa-ssh-sg-${var.environment}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3306"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh", "mysql"]
}

# Firewall rule for web services
resource "google_compute_firewall" "allow_web_services" {
  name    = "moa-lb-sg-${var.environment}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8000", "8080", "9090", "3000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web", "api"]
}

# Firewall rule for HTTP, HTTPS, and health checks
resource "google_compute_firewall" "allow_http_https_health" {
  name    = "moa-http-health-${var.environment}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]  # Common health check port
  }

  # Allow Google Cloud health checkers
  source_ranges = [
    "0.0.0.0/0",
    "130.211.0.0/22",    # Google Cloud Load Balancer health checks
    "35.191.0.0/16"      # Google Cloud health checks
  ]
}

# Static external IP address
resource "google_compute_address" "vm_static_ip" {
  name         = "moa-be-ec2-${var.environment}-elasticip"
  region       = var.region
  address_type = "EXTERNAL"
}

# Compute Instance
resource "google_compute_instance" "vm_instance" {
  name         = "moa-be-ec2-${var.environment}"
  machine_type = "e2-medium"
  zone         = "asia-northeast3-c"
  tags         = ["ssh", "web", "api", "mysql", "http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 60
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "192.168.10.3"
    access_config {
      nat_ip = google_compute_address.vm_static_ip.address
    }
  }
}

# Make the bucket publicly accessible
resource "google_storage_bucket_iam_member" "public_access" {
  bucket = google_storage_bucket.static_website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Static external IP address for AI server
resource "google_compute_address" "ai_static_ip" {
  name         = "moa-ai-ec2-${var.environment}-elasticip"
  region       = var.region
  address_type = "EXTERNAL"
}

# AI Server Instance with GPU
resource "google_compute_instance" "ai_instance" {
  name         = "moa-ai-ec2-${var.environment}"
  machine_type = "n1-standard-4"
  zone         = "asia-northeast3-c"
  tags         = ["ssh", "web", "api", "mysql", "http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 130
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "192.168.10.5"
    access_config {
      nat_ip = google_compute_address.ai_static_ip.address
    }
  }

  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }

  # Required when using GPUs
  scheduling {
    on_host_maintenance = "TERMINATE"
  }
}

# Manual instance group for backend VM
resource "google_compute_instance_group" "backend_group" {
  name        = "moa-be-ec2-group-${var.environment}"
  description = "Backend instance group"
  zone        = "asia-northeast3-c"
  
  instances = [
    google_compute_instance.vm_instance.id
  ]

  named_port {
    name = "http"
    port = 80
  }
  
  named_port {
    name = "api"
    port = 8080
  }
}

# Frontend Load Balancer Configuration

# Static IP for frontend load balancer
resource "google_compute_global_address" "frontend_lb_ip" {
  name = "moa-fe-lb-ip-${var.environment}"
}

# Backend bucket for static website
resource "google_compute_backend_bucket" "frontend_bucket" {
  name        = "moa-fe-frontend-backend-${var.environment}"
  bucket_name = google_storage_bucket.static_website.name
  enable_cdn  = true
}

# URL map for frontend
resource "google_compute_url_map" "frontend_url_map" {
  name            = "moa-fe-url-map-${var.environment}"
  default_service = google_compute_backend_bucket.frontend_bucket.id
}

# HTTP proxy for frontend
resource "google_compute_target_http_proxy" "frontend_http_proxy" {
  name    = "moa-fe-http-proxy-${var.environment}"
  url_map = google_compute_url_map.frontend_url_map.id
}

# HTTP forwarding rule for frontend
resource "google_compute_global_forwarding_rule" "frontend_http_forwarding_rule" {
  name       = "moa-fe-http-rule-${var.environment}"
  target     = google_compute_target_http_proxy.frontend_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.frontend_lb_ip.address
}

# SSL certificate for frontend HTTPS
# Uncomment and configure when you have a certificate
# resource "google_compute_ssl_certificate" "frontend_certificate" {
#   name        = "moa-fe-ssl-cert-${var.environment}"
#   private_key = file("path/to/private.key")
#   certificate = file("path/to/certificate.crt")
# }

# HTTPS proxy for frontend
# resource "google_compute_target_https_proxy" "frontend_https_proxy" {
#   name             = "moa-fe-https-proxy-${var.environment}"
#   url_map          = google_compute_url_map.frontend_url_map.id
#   ssl_certificates = ["projects/PROJECT_ID/global/sslCertificates/moa-fe-ssl-cert-${var.environment}"]
#   # Replace PROJECT_ID with your actual project ID
# }

# HTTPS forwarding rule for frontend
# resource "google_compute_global_forwarding_rule" "frontend_https_forwarding_rule" {
#   name       = "moa-fe-https-rule-${var.environment}"
#   target     = google_compute_target_https_proxy.frontend_https_proxy.id
#   port_range = "443"
#   ip_address = google_compute_global_address.frontend_lb_ip.address
# }

# Backend Load Balancer Configuration

# Health check for backend service
resource "google_compute_health_check" "backend_health_check" {
  name               = "moa-be-ec2-healthcheck-${var.environment}"
  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

# Backend service
resource "google_compute_backend_service" "backend_service" {
  name                  = "moa-be-ec2-service-${var.environment}"
  protocol              = "HTTP"
  port_name             = "api"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.backend_health_check.id]
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_instance_group.backend_group.id
  }
}

# Static IP for backend load balancer
resource "google_compute_global_address" "backend_lb_ip" {
  name = "moa-be-lb-ip-${var.environment}"
}

# URL map for backend
resource "google_compute_url_map" "backend_url_map" {
  name            = "moa-be-url-map-${var.environment}"
  default_service = google_compute_backend_service.backend_service.id
  
  host_rule {
    hosts        = ["backend.moagenda.com"]
    path_matcher = "backend-paths"
  }
  
  path_matcher {
    name            = "backend-paths"
    default_service = google_compute_backend_service.backend_service.id
    
    path_rule {
      paths   = ["/api/*", "/api/v1/*", "/*"]
      service = google_compute_backend_service.backend_service.id
    }
  }
}

# HTTP proxy for backend
resource "google_compute_target_http_proxy" "backend_http_proxy" {
  name    = "moa-be-http-proxy-${var.environment}"
  url_map = google_compute_url_map.backend_url_map.id
}

# HTTP forwarding rule for backend
resource "google_compute_global_forwarding_rule" "backend_http_forwarding_rule" {
  name       = "moa-be-http-rule-${var.environment}"
  target     = google_compute_target_http_proxy.backend_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.backend_lb_ip.address
}

# SSL certificate for backend HTTPS
# Uncomment and configure when you have a certificate
# resource "google_compute_ssl_certificate" "backend_certificate" {
#   name        = "moa-be-ssl-cert-${var.environment}"
#   private_key = file("path/to/private.key")
#   certificate = file("path/to/certificate.crt")
# }

# HTTPS proxy for backend
#resource "google_compute_target_https_proxy" "backend_https_proxy" {
#  name             = "moa-be-https-proxy-${var.environment}"
#  url_map          = google_compute_url_map.backend_url_map.id
#  ssl_certificates = ["projects/PROJECT_ID/global/sslCertificates/moa-be-ssl-cert-${var.environment}"]
#  # Replace PROJECT_ID with your actual project ID
#}

# HTTPS forwarding rule for backend
#resource "google_compute_global_forwarding_rule" "backend_https_forwarding_rule" {
#  name       = "moa-be-https-rule-${var.environment}"
#  target     = google_compute_target_https_proxy.backend_https_proxy.id
#  port_range = "443"
#  ip_address = google_compute_global_address.backend_lb_ip.address
#}