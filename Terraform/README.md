# GCP Terraform Infrastructure

This repository contains Terraform code to deploy a basic infrastructure on Google Cloud Platform.

## Resources Created

- VPC Network
- Subnet
- Firewall rule for SSH access
- Compute VM instance

## Prerequisites

- Terraform installed (version >= 1.0)
- Google Cloud SDK installed
- GCP project with billing enabled
- Service account with appropriate permissions

## Usage

1. Clone this repository
2. Create a `terraform.tfvars` file based on the example:
   ```
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edit `terraform.tfvars` with your GCP project ID and other settings
4. Initialize Terraform:
   ```
   terraform init
   ```
5. Plan the deployment:
   ```
   terraform plan
   ```
6. Apply the configuration:
   ```
   terraform apply
   ```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| project_id | The GCP project ID | (required) |
| region | The GCP region for resources | us-central1 |
| zone | The GCP zone for zonal resources | us-central1-a |
| environment | Environment name (dev, staging, prod) | dev |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| subnet_id | ID of the subnet |
| instance_name | Name of the VM instance |
| instance_external_ip | External IP of the VM instance |