#!/bin/bash
set -e

# Start Terraform to create the project and bucket
terraform apply -var="billing_account=$BILLING_ID" -target=google_project.yolo_project -target=google_storage_bucket.assets -auto-approve

PROJECT_ID=$(terraform output -raw project_id)

# Enable Artifact Registry manually (Terraform can be slow here)
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID

# Create Repo & Push Image
gcloud artifacts repositories create yolo-repo --repository-format=docker --location=us-central1 --project=$PROJECT_ID
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

docker tag yolo-fastapi:v2 us-central1-docker.pkg.dev/$PROJECT_ID/yolo-repo/yolo-fastapi:v2
docker push us-central1-docker.pkg.dev/$PROJECT_ID/yolo-repo/yolo-fastapi:v2

# Upload Weights
gsutil cp yolov8n.pt gs://yolo-assets-$PROJECT_ID/weights/yolov8n.pt

# Run full Terraform to deploy GKE and the App
terraform apply -var="billing_account=$BILLING_ID" -auto-approve