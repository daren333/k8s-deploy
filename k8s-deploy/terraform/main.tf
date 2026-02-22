# 1. Variables & Providers
variable "project_id" { default = "project-5a33486e-38f2-4a82-b50" }
variable "region"     { default = "us-central1" }

provider "google" {
  project = var.project_id
  region  = var.region
}

# Get GKE credentials for the kubernetes provider
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# 2. Infrastructure: GKE Autopilot
resource "google_container_cluster" "primary" {
  name     = "yolo-repo-cluster"
  location = var.region
  enable_autopilot = true
}

# 3. Infrastructure: Storage Bucket
resource "google_storage_bucket" "assets" {
  name     = "yolo-assets"
  location = var.region
  force_destroy = true
}

# 4. IAM: Workload Identity Setup
# This replaces the manual 'gcloud' commands we ran earlier
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/default]"
}

resource "google_storage_bucket_iam_member" "viewer" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[default/default]"
}

# 5. The YOLO Deployment (with Sidecar & InitContainer)
resource "kubernetes_deployment" "yolo" {
  metadata {
    name = "yolo-fastapi-deployment"
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "yolo-fastapi" } }
    template {
      metadata {
        labels = { app = "yolo-fastapi" }
        annotations = {
          # This links the K8s pod to the Google Service Account
          "iam.gke.io/gcp-service-account" = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
        }
      }
      spec {
        volume {
          name = "shared-data"
          empty_dir {}
        }

        init_container {
          name  = "weights-downloader"
          image = "google/cloud-sdk:slim"
          command = ["/bin/sh", "-c"]
          args = ["gsutil cp gs://${google_storage_bucket.assets.name}/weights/yolov8n.pt /data/yolov8n.pt"]
          volume_mount {
            name       = "shared-data"
            mount_path = "/data"
          }
        }

        container {
          name  = "yolo-fastapi"
          image = "us-central1-docker.pkg.dev/${var.project_id}/yolo-repo/yolo-fastapi:v2"
          
          port { container_port = 8000 }

          env {
            name  = "WEIGHTS_PATH"
            value = "/data/yolov8n.pt"
          }
          env {
            name  = "LOG_FILE_PATH"
            value = "/data/predictions.log"
          }

          volume_mount {
            name       = "shared-data"
            mount_path = "/data"
          }
        }

        container {
          name  = "log-recorder-sidecar"
          image = "google/cloud-sdk:slim"
          command = ["/bin/sh", "-c"]
          args = ["while true; do if [ -f /data/predictions.log ]; then gsutil cp /data/predictions.log gs://${google_storage_bucket.assets.name}/logs/$(hostname).log; fi; sleep 60; done"]
          
          volume_mount {
            name       = "shared-data"
            mount_path = "/data"
          }
        }
      }
    }
  }
}

# 6. Load Balancer Service
resource "kubernetes_service" "yolo" {
  metadata { name = "yolo-fastapi-service" }
  spec {
    selector = { app = "yolo-fastapi" }
    type     = "LoadBalancer"
    port {
      port        = 80
      target_port = 8000
    }
  }
}

data "google_project" "project" {}