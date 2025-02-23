#!/bin/bash

# Function to get the current network interface IP
get_ip_address() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1
}

ip_address=$(get_ip_address)

# Parse command line arguments
while getopts ":s:" opt; do
  case $opt in
    s) storage_path="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [ -z "$storage_path" ]; then
  echo "Usage: $0 -s <storage_path>"
  exit 1
fi

# Replace placeholders in kustomization.yaml
sed -i "s|<ip_address>|$ip_address|g" ../overlays/microk8s/kustomization.yaml
sed -i "s|<storage_path>|$storage_path|g" ../overlays/microk8s/kustomization.yaml

# Apply kustomize installation
kubectl kustomize ../overlays/microk8s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -