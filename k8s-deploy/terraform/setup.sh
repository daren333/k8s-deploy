#!/bin/bash
set -e

# --- Helper Function for Logging ---
log() {
  echo -e "[$(date +'%T')] $1"
}

log "Starting YOLO Deployment Setup..."

# --- 1. Check/Prompt for Billing ID ---
if [ -z "$BILLING_ID" ]; then
  log "Warning: BILLING_ID environment variable not found."
  read -p "Please enter your Google Billing Account ID: " BILLING_ID
  if [ -z "$BILLING_ID" ]; then
    log "Error: Billing ID is required. Exiting."
    exit 1
  fi
fi

# --- 2. Phase 1: Create Project & Bucket ---
log "Phase 1: Provisioning Project and Storage..."
terraform apply -var="billing_account=$BILLING_ID" \
  -target=google_project.yolo_project \
  -target=google_storage_bucket.assets \
  -auto-approve

PROJECT_ID=$(terraform output -raw project_id)
REGION="us-central1"
REPO_NAME="yolo-repo"

# --- 3. Phase 2: Build Image & Prepare Assets ---
log "Phase 2: Preparing Registry and Assets..."
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID

# Check if Repository Exists
REPO_EXISTS=$(gcloud artifacts repositories list \
  --project=$PROJECT_ID --location=$REGION \
  --filter="name:projects/$PROJECT_ID/locations/$REGION/repositories/$REPO_NAME" \
  --format="value(name)")

if [ -z "$REPO_EXISTS" ]; then
  log "Creating new Artifact Registry repository..."
  gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker --location=$REGION --project=$PROJECT_ID
else
  log "Repository '$REPO_NAME' already exists. Skipping creation."
fi

gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

# Build the local Docker image
log "Building and pushing Docker image..."
docker build -t yolo-fastapi:v4 -f ../Dockerfile ..

# Tag and Push to the new project's registry
IMAGE_PATH="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/yolo-fastapi:v4"
docker tag yolo-fastapi:v4 "$IMAGE_PATH"
docker push "$IMAGE_PATH"

# Upload Weights to the new bucket
log "Uploading model weights to GCS..."
gsutil cp ../yolov8n.pt "gs://yolo-assets-$PROJECT_ID/weights/yolov8n.pt"

# --- 4. Phase 3: Final Deploy ---
log "Phase 3a: Deploying GKE Cluster (This takes 10-15 minutes)..."
terraform apply -var="billing_account=$BILLING_ID" \
  -target=google_container_cluster.primary \
  -auto-approve

log "Phase 3b: Deploying Kubernetes Services and App..."
# Now that the cluster exists, Terraform can connect and apply the manifests
terraform apply -var="billing_account=$BILLING_ID" -auto-approve

log "Setup Complete!"
terraform output