variable "project_name" {
  description = "Display name for the GCP project"
  type        = string
}

variable "billing_account" {
  description = "GCP billing account ID to link to the new project"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Name prefix used for GKE cluster, Artifact Registry, and K8s resources"
  type        = string
  default     = "yolo-repo"
}

variable "replicas" {
  description = "Number of pod replicas for the deployment"
  type        = number
  default     = 2
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
