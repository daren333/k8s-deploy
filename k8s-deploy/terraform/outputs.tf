output "project_id" {
  value       = google_project.yolo_project.project_id
  description = "The unique ID of the newly created GCP project"
}

output "project_number" {
  value       = google_project.yolo_project.number
  description = "The project number (used for service account names)"
}

output "bucket_name" {
  value       = google_storage_bucket.assets.name
  description = "The name of the GCS bucket created for weights and logs"
}

output "ingress_ip" {
  # try() prevents Terraform from crashing if the IP list is currently empty
  value       = try(kubernetes_ingress_v1.yolo_ingress.status[0].load_balancer[0].ingress[0].ip, "Provisioning in progress... check GCP Console")
  description = "The public IP of your GKE Ingress (Load Balancer)"
}