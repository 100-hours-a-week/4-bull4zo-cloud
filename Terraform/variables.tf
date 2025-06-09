variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "The GCP zone for zonal resources"
  type        = string
  default     = "asia-northeast3-c"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "frontend_domain" {
  description = "Domain name for the frontend SSL certificate"
  type        = string
  default     = "moagenda.com"
}

variable "backend_domain" {
  description = "Domain name for the backend SSL certificate"
  type        = string
  default     = "backend.moagenda.com"
}