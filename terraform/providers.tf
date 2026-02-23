terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# The default provider (used to create the project)
provider "google" {
  region = var.region
}

# The project-specific provider (used for resources inside the project)
provider "google" {
  alias   = "project_context"
  project = google_project.yolo_project.project_id
  region  = var.region
}