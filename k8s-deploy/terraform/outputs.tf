output "project_id" {
  description = "GCP project ID"
  value       = google_project.this.project_id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "artifact_registry_url" {
  description = "Docker image registry URL (push target)"
  value       = local.registry_url
}

output "load_balancer_ip" {
  description = "External IP of the LoadBalancer service"
  value       = kubernetes_service.app.status[0].load_balancer[0].ingress[0].ip
}
