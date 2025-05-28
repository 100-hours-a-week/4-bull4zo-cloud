output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = google_compute_subnetwork.subnet.id
}

output "instance_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance.vm_instance.name
}

output "instance_external_ip" {
  description = "External IP of the VM instance"
  value       = google_compute_address.vm_static_ip.address
}

output "instance_group_name" {
  description = "Name of the backend instance group"
  value       = google_compute_instance_group.backend_group.name
}

output "ai_instance_name" {
  description = "Name of the AI VM instance"
  value       = google_compute_instance.ai_instance.name
}

output "ai_instance_external_ip" {
  description = "External IP of the AI VM instance"
  value       = google_compute_instance.ai_instance.network_interface[0].access_config[0].nat_ip
}

output "ai_instance_name" {
  description = "Name of the AI VM instance"
  value       = google_compute_instance.ai_instance.name
}

output "ai_instance_external_ip" {
  description = "External IP of the AI VM instance"
  value       = google_compute_address.ai_static_ip.address
}

output "frontend_bucket_name" {
  description = "Name of the frontend static website bucket"
  value       = google_storage_bucket.static_website.name
}

output "frontend_bucket_url" {
  description = "URL of the frontend static website"
  value       = "https://storage.googleapis.com/${google_storage_bucket.static_website.name}"
}

output "frontend_load_balancer_ip" {
  description = "IP address of the frontend load balancer"
  value       = google_compute_global_address.frontend_lb_ip.address
}

output "backend_load_balancer_ip" {
  description = "IP address of the backend load balancer"
  value       = google_compute_global_address.backend_lb_ip.address
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.backend_service.name
}