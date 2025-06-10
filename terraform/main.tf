# MOA 프로젝트 GCP 인프라 생성 Terraform 코드


## 네트워크 설정
# 서비스용 VPC 생성
resource "google_compute_network" "vpc" {
  name                    = "moa-main-vpc-${var.environment}"
  auto_create_subnetworks = false
}

# 백엔드 서브넷 생성
resource "google_compute_subnetwork" "subnet" {
  name          = "moa-backend-sub-${var.environment}-a"
  ip_cidr_range = "192.168.10.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 정적 배포용 Cloud Storage 버킷 생성
resource "google_storage_bucket" "static_website" {
  name          = "${var.project_id}-${var.environment}-frontend"
  location      = var.region
  force_destroy = true

# 모든 트래픽을 index.html로 리다이렉트
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
# 버킷 공개 접근 설정
resource "google_storage_bucket_iam_member" "public_access" {
  bucket = google_storage_bucket.static_website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}




## 방화벽
# SSH, MySQL, Redis 방화벽 규칙
resource "google_compute_firewall" "allow_ssh_mysql" {
  name    = "moa-ssh-sg-${var.environment}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3306", "6379"]
  }

  source_ranges = ["192.168.0.0/16"]
  target_tags   = ["ssh", "mysql", "redis"]
}

# 웹 서비스 및 사용 API 방화벽 규칙
resource "google_compute_firewall" "allow_web_services" {
  name    = "moa-lb-sg-${var.environment}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8000", "8080", "9090", "3000", "3100", "5601", "8200", "9200", "9300"]
  }

  source_ranges = ["192.168.0.0/16"]
  target_tags   = ["web", "api"]
}

# HTTP/HTTPS Health Check 방화벽 규칙
resource "google_compute_firewall" "allow_http_https_health" {
  name    = "moa-http-health-${var.environment}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]  # Common health check port
  }

  # 구글 클라우드 로드 밸런서 헬스 체크를 위한 IP 범위
  source_ranges = [
    "192.168.0.0/16",
    "130.211.0.0/22",    # Google Cloud Load Balancer health checks
    "35.191.0.0/16"      # Google Cloud health checks
  ]
}




## 인스턴스 생성
# 백엔드 서버 인스턴스
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
  }
}

# AI 서버 인스턴스
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
  }

  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }

  # GPU 사용을 위해 필요 - 유지보수 시에 인스턴스 종료(정지)
  scheduling {
    on_host_maintenance = "TERMINATE"
  }
}

# DB 서버 인스턴스
resource "google_compute_instance" "db_instance" {
  name         = "moa-db-ec2-${var.environment}"
  machine_type = "e2-small"
  zone         = "asia-northeast3-c"
  tags         = ["mysql", "db"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "192.168.10.10"
  }
}

# Redis 서버 인스턴스
resource "google_compute_instance" "redis_instance" {
  name         = "moa-redis-ec2-${var.environment}"
  machine_type = "e2-small"
  zone         = "asia-northeast3-c"
  tags         = ["redis", "cache"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "192.168.10.15"
  }
}

# 백엔드 인스턴스 그룹 생성
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




## 프론트엔드 로드 밸런서 설정
# FE 로드 밸런서 고정 IP 주소
resource "google_compute_global_address" "frontend_lb_ip" {
  name = "moa-fe-lb-ip-${var.environment}"
}

# 정적 배포용 백엔드 버킷 설정
resource "google_compute_backend_bucket" "frontend_bucket" {
  name        = "moa-fe-frontend-backend-${var.environment}"
  bucket_name = google_storage_bucket.static_website.name
  enable_cdn  = true
}

# 로드밸런서 URL 맵 설정
resource "google_compute_url_map" "frontend_url_map" {
  name            = "moa-fe-url-map-${var.environment}"
  default_service = google_compute_backend_bucket.frontend_bucket.id
}

# 프론트엔드 HTTP proxy 
resource "google_compute_target_http_proxy" "frontend_http_proxy" {
  name    = "moa-fe-http-proxy-${var.environment}"
  url_map = google_compute_url_map.frontend_url_map.id
}

# 프론트엔드 HTTP 포워딩 규칙
resource "google_compute_global_forwarding_rule" "frontend_http_forwarding_rule" {
  name       = "moa-fe-http-rule-${var.environment}"
  target     = google_compute_target_http_proxy.frontend_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.frontend_lb_ip.address
}

# 프론트엔드 SSL 인증서
resource "google_compute_managed_ssl_certificate" "frontend_certificate" {
  name = "moa-fe-ssl-cert-${var.environment}"
  
  managed {
    domains = [var.frontend_domain]
  }
}

# 프론트엔드 HTTPS proxy
resource "google_compute_target_https_proxy" "frontend_https_proxy" {
  name             = "moa-fe-https-proxy-${var.environment}"
  url_map          = google_compute_url_map.frontend_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.frontend_certificate.id]
}

# 프론트엔드 HTTPS 포워딩 규칙
resource "google_compute_global_forwarding_rule" "frontend_https_forwarding_rule" {
  name       = "moa-fe-https-rule-${var.environment}"
  target     = google_compute_target_https_proxy.frontend_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.frontend_lb_ip.address
}




## 백엔드 로드 밸런서 설정
# 백엔드 고정 IP 주소
resource "google_compute_global_address" "backend_lb_ip" {
  name = "moa-be-lb-ip-${var.environment}"
}

# 백엔드 서비스 헬스체크
resource "google_compute_health_check" "backend_health_check" {
  name               = "moa-be-ec2-healthcheck-${var.environment}"
  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

# 백엔드 서비스 설정
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

# 백엔드 URL 맵 설정
resource "google_compute_url_map" "backend_url_map" {
  name            = "moa-be-url-map-${var.environment}"
  default_service = google_compute_backend_service.backend_service.id
  
  host_rule {
    hosts        = [var.backend_domain]
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

# 백엔드 HTTP 프록시
resource "google_compute_target_http_proxy" "backend_http_proxy" {
  name    = "moa-be-http-proxy-${var.environment}"
  url_map = google_compute_url_map.backend_url_map.id
}

# 백엔드 HTTP 포워딩 규칙
resource "google_compute_global_forwarding_rule" "backend_http_forwarding_rule" {
  name       = "moa-be-http-rule-${var.environment}"
  target     = google_compute_target_http_proxy.backend_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.backend_lb_ip.address
}

# 백엔드 HTTPS SSL 인증서
resource "google_compute_managed_ssl_certificate" "backend_certificate" {
  name = "moa-be-ssl-cert-${var.environment}"
  managed {
    domains = [var.backend_domain]
  }
}

# 백엔드 HTTPS 프록시
resource "google_compute_target_https_proxy" "backend_https_proxy" {
  name             = "moa-be-https-proxy-${var.environment}"
  url_map          = google_compute_url_map.backend_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.backend_certificate.id]
}

# 백엔드 HTTPS 포워딩 규칙
resource "google_compute_global_forwarding_rule" "backend_https_forwarding_rule" {
  name       = "moa-be-https-rule-${var.environment}"
  target     = google_compute_target_https_proxy.backend_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.backend_lb_ip.address
}