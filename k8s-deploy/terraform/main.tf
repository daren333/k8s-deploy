resource "random_id" "project_suffix" {
  byte_length = 4
}

resource "google_project" "yolo_project" {
  name            = "YOLO-Detector-Project"
  project_id      = "yolo-deploy-${random_id.project_suffix.hex}"
  billing_account = var.billing_account
  org_id          = var.org_id
}

# 2. Enable Required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])
  project = google_project.yolo_project.project_id
  service = each.key
  disable_on_destroy = false
}

# 3. Infrastructure: GKE & Storage
resource "google_container_cluster" "primary" {
  name             = "yolo-repo-cluster"
  location         = var.region
  enable_autopilot = true
  project          = google_project.yolo_project.project_id
  depends_on       = [google_project_service.apis]
}

resource "google_storage_bucket" "assets" {
  name          = "yolo-assets-${google_project.yolo_project.project_id}"
  project       = google_project.yolo_project.project_id
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

# 4. Identity Linking (Workload Identity)
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = "projects/${google_project.yolo_project.project_id}/serviceAccounts/${google_project.yolo_project.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${google_project.yolo_project.project_id}.svc.id.goog[default/default]"
}

resource "google_storage_bucket_iam_member" "storage_access" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_project.yolo_project.project_id}.svc.id.goog[default/default]"
}

# 5. Kubernetes & TLS Resources
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}

# SSL Managed Certificate
resource "kubernetes_manifest" "managed_cert" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "yolo-managed-cert"
      namespace = "default"
    }
    spec = {
      domains = ["yolo-test.duckdns.org"]
    }
  }
}

# GKE Ingress (The Cloud Load Balancer)
resource "kubernetes_ingress_v1" "yolo_ingress" {
  metadata {
    name = "yolo-fastapi-ingress"
    annotations = {
      "kubernetes.io/ingress.class"            = "gce"
      "networking.gke.io/managed-certificates" = "yolo-managed-cert"
      "kubernetes.io/ingress.allow-http"       = "true"
    }
  }
  spec {
    rule {
      host = "yolo-test.duckdns.org"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "yolo-fastapi-service"
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}

# 6. Deployment & Service
resource "kubernetes_deployment" "yolo" {
  metadata {
    name = "yolo-fastapi-deployment"
    namespace = "default"
    labels = { app = "yolo-fastapi" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "yolo-fastapi" } }
    template {
      metadata {
        labels = { app = "yolo-fastapi" }
        annotations = {
          # Dynamically links to the new project's default service account
          "iam.gke.io/gcp-service-account" = "${google_project.yolo_project.number}-compute@developer.gserviceaccount.com"
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
          # Points to the dynamically created bucket
          args = ["gsutil cp gs://${google_storage_bucket.assets.name}/weights/yolov8n.pt /data/yolov8n.pt"]
          volume_mount {
            name       = "shared-data"
            mount_path = "/data"
          }
        }

        container {
          name  = "yolo-fastapi"
          # Points to the new project's registry
          image = "us-central1-docker.pkg.dev/${google_project.yolo_project.project_id}/yolo-repo/yolo-fastapi:v4"
          
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

resource "kubernetes_service" "yolo" {
  metadata {
    name = "yolo-fastapi-service"
    namespace = "default"
  }
  spec {
    selector = { app = "yolo-fastapi" }
    type     = "NodePort" # Required for GKE Ingress
    port {
      port        = 80
      target_port = 8000
    }
  }
}
