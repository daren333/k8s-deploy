#!/bin/bash

echo "🚀 Starting full cleanup of YOLO GKE environment..."

# 1. Delete Kubernetes resources first
# This ensures the Google Load Balancer (Ingress) is deleted cleanly.
# If you don't do this, Terraform might hang trying to delete the network.
echo "🗑️ Deleting Kubernetes manifests..."
kubectl delete -f deployment.yml

# Wait a moment for the Load Balancer to detach
echo "⏳ Waiting 60 seconds for Cloud Load Balancer to release..."
sleep 60

# 2. Use Terraform to destroy the infrastructure
echo "🏗️ Running Terraform Destroy..."
cd terraform
terraform destroy -auto-approve

# 3. Final verification
echo "🔍 Checking for any lingering disks or IPs..."
gcloud compute forwarding-rules list
gcloud compute target-http-proxies list
gcloud compute static-ips list

echo "✅ Cleanup complete! Your wallet is safe."