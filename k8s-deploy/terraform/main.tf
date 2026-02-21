variable "project_id" {
  description = "The ID of the existing GCP project"
  type        = string
}

# ---------- enable required APIs ----------

resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

# ---------- Artifact Registry ----------

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.app_name
  format        = "DOCKER"

  depends_on = [google_project_service.artifact_registry]
}

locals {
  registry_url = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
  image        = "${local.registry_url}/${var.app_name}:${var.image_tag}"
}

# ---------- GKE Autopilot cluster ----------

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = "${var.app_name}-cluster"
  location = var.region

  enable_autopilot = true

  deletion_protection = false

  depends_on = [google_project_service.container]
}

/*# ---------- Kubernetes Deployment ----------

resource "kubernetes_deployment" "app" {
  metadata {
    name = var.app_name
    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }

      spec {
        container {
          name  = var.app_name
          image = local.image

          port {
            container_port = 8000
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
          }
        }
      }
    }
  }

  depends_on = [google_container_cluster.this]
}

# ---------- Kubernetes Service (LoadBalancer) ----------

resource "kubernetes_service" "app" {
  metadata {
    name = var.app_name
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      port        = 80
      target_port = 8000
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment.app]
}*/
