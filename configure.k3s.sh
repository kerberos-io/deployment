#!/bin/bash

################################################################################
# Kerberos K3s Deployment Script
#
# This script automates the deployment of the Kerberos surveillance system
# on K3s (lightweight Kubernetes). It configures and deploys:
# - Kerberos Hub (web interface and API)
# - Kerberos Vault (video storage)
# - Kerberos Agents (camera connectors)
# - Supporting services (MongoDB, RabbitMQ, VerneMQ MQTT broker)
#
# Usage:
#   Deploy:  ./configure.k3s.sh apply -s <storage_path> [-i <ip_address>]
#   Remove:  ./configure.k3s.sh delete
#
# Examples:
#   ./configure.k3s.sh apply -s /home/user/kerberos-data
#   ./configure.k3s.sh delete
################################################################################

# Function to detect the current machine's IP address
# This IP will be used for:
# - MQTT broker connections (agents → VerneMQ)
# - TURN server for WebRTC live video streaming
# - Hub API external access
get_ip_address() {
    # Get the first non-loopback IPv4 address
    # If you have multiple network interfaces, you may want to specify one manually
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -n 1
}

# Parse command line arguments
# First argument is the command: "apply" or "delete"
command=$1
shift

# Parse optional flags:
# -s: Storage path for video recordings (required for apply)
# -i: IP address for external access (auto-detected if not provided)
while getopts ":s:i:" opt; do
  case $opt in
    s) storage_path="$OPTARG"
    ;;
    i) ip_address="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

################################################################################
# APPLY COMMAND - Deploy Kerberos to K3s
################################################################################
if [ "$command" == "apply" ]; then
  # Validate that storage path is provided
  if [ -z "$storage_path" ]; then
    echo "Error: Storage path is required for deployment"
    echo "Usage: $0 apply -s <storage_path> [-i <ip_address>]"
    exit 1
  fi

  # Auto-detect IP address if not provided
  if [ -z "$ip_address" ]; then
    ip_address=$(get_ip_address)
    echo "Auto-detected IP address: $ip_address"
    echo "If this is incorrect, run with: $0 apply -s $storage_path -i <correct_ip>"
  fi

  echo "========================================="
  echo "Kerberos K3s Deployment"
  echo "========================================="
  echo "Storage path: $storage_path"
  echo "IP address:   $ip_address"
  echo "========================================="
  echo ""

  # Create a temporary working copy of the K3s kustomization file
  # This allows us to modify it without affecting the original template
  cp ./overlays/k3s/kustomization.yaml ./kustomization.yaml

  # Replace placeholder values in the kustomization file:
  # 1. Replace "localhost" with actual IP (for MQTT, TURN, Hub API)
  # 2. Replace "/media/Storage" with user's storage path
  echo "Configuring deployment with your settings..."
  sed -i "s|localhost|$ip_address|g" ./kustomization.yaml
  sed -i "s|/media/Storage|$storage_path|g" ./kustomization.yaml

  # Adjust base path reference for kustomize to work from deployment root
  # Changes "../../base" to "./base" since we copied the file here
  sed -i "s|../../base|./base|g" ./kustomization.yaml

  # Deploy to K3s using kubectl kustomize
  # --enable-helm: Allows Helm charts to be included in kustomization
  # --load-restrictor LoadRestrictionsNone: Allows loading files from parent directories
  echo "Deploying Kerberos to K3s..."
  echo "This may take 5-10 minutes as Docker images are downloaded..."
  echo ""
  kubectl kustomize ./ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -

  # Clean up the temporary kustomization file
  rm ./kustomization.yaml

  echo ""
  echo "========================================="
  echo "Deployment Complete!"
  echo "========================================="
  echo ""
  echo "Access your Kerberos services:"
  echo "- Hub (Web Interface): http://$ip_address:32080"
  echo "- Vault (Storage API):  http://$ip_address:30080"
  echo ""
  echo "Check deployment status:"
  echo "  kubectl get pods --all-namespaces"
  echo ""
  echo "View logs for a specific pod:"
  echo "  kubectl logs -n kerberos-hub <pod-name>"
  echo ""
  echo "Next steps:"
  echo "1. Wait for all pods to be in 'Running' state (this may take a few minutes)"
  echo "2. Login to Hub at http://$ip_address:32080"
  echo "3. Login to Vault at http://$ip_address:30080 and update account credentials"
  echo "========================================="

################################################################################
# DELETE COMMAND - Remove Kerberos from K3s
################################################################################
elif [ "$command" == "delete" ]; then
  echo "========================================="
  echo "Removing Kerberos from K3s"
  echo "========================================="
  echo ""
  echo "Warning: This will delete all Kerberos components"
  echo "Video recordings in your storage path will NOT be deleted"
  echo ""

  # Create a temporary working copy of the K3s kustomization file
  cp ./overlays/k3s/kustomization.yaml ./kustomization.yaml

  # Adjust base path reference
  sed -i "s|../../base|./base|g" ./kustomization.yaml

  # Delete all Kerberos resources from K3s
  echo "Deleting Kerberos resources..."
  kubectl kustomize ./ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl delete -f -

  # Clean up the temporary kustomization file
  rm ./kustomization.yaml

  echo ""
  echo "========================================="
  echo "Kerberos has been removed from K3s"
  echo "========================================="
  echo ""
  echo "Your video recordings in the storage path were NOT deleted"
  echo "To completely remove all data, manually delete your storage directory"

################################################################################
# INVALID COMMAND
################################################################################
else
  echo "Kerberos K3s Deployment Script"
  echo ""
  echo "Usage:"
  echo "  Deploy:  $0 apply -s <storage_path> [-i <ip_address>]"
  echo "  Remove:  $0 delete"
  echo ""
  echo "Options:"
  echo "  -s <storage_path>  Path where video recordings will be stored (required for apply)"
  echo "  -i <ip_address>    IP address for external access (auto-detected if not provided)"
  echo ""
  echo "Examples:"
  echo "  $0 apply -s /mnt/storage -i 192.168.1.0"
  echo "  $0 apply -s /home/user/kerberos-data"
  echo "  $0 delete"
  exit 1
fi
