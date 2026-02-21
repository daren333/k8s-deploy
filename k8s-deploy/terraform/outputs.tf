output "project_id" {
  description = "GCP project ID"
  value       = var.project_id # Point to your variable instead of the deleted resource
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "artifact_registry_url" {
  description = "Docker image registry URL (push target)"
  # Ensure this uses var.project_id as well
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}"
}

# The load_balancer_ip output has been removed because 
# the service is not managed by Terraform right now.