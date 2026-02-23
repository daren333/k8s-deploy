#!/bin/bash
set -e

# --- Helper Function for Logging ---
log() {
  echo -e "[$(date +'%T')] $1"
}

log "Starting full cleanup of YOLO GKE environment..."

# Optional: Prompt for Billing ID if it's not in your terraform.tfvars
if [ -z "$BILLING_ID" ]; then
  log "Warning: BILLING_ID environment variable not found."
  read -p "Please enter your Google Billing Account ID to authorize destruction: " BILLING_ID
  export TF_VAR_billing_account=$BILLING_ID
fi

log "Running Terraform Destroy..."
# This will safely tear down the Ingress, the Cluster, the Bucket, the Registry, and finally the Project itself.
terraform destroy -auto-approve

log "Cleanup complete!"