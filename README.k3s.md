# Deployment on K3S with Kustomize

⏱️ **Time:** installation within 25min

💻 **Environment:** tested on Debian 12

[<img src="https://github.com/kerberos-io/deployment/workflows/Deploy%20on%20Microk8s/badge.svg"/>](https://github.com/kerberos-io/deployment/actions/workflows/microk8s.yaml)

---

K3S is a lightweight, fast, and secure Kubernetes distribution designed for resource-constrained environments and edge computing use cases. Developed by Rancher (now part of SUSE), K3S is a certified Kubernetes distribution packaged as a single binary that can be installed with a single command. It is ideal for local development, CI/CD pipelines, IoT, edge deployments, and home lab environments due to its small footprint (less than 100MB) and ease of use. K3S includes essential Kubernetes components such as CoreDNS and a local-path storage provisioner by default, making it a convenient choice for both beginners and experienced Kubernetes users.

In this tutorial, we will guide you through the installation of the complete stack, which includes the Agent, Factory, Vault, and Hub. This setup enables the storage of recordings from multiple cameras at the edge, facilitating local data processing and ensuring secure and efficient management of video streams. To simplify our efforts we will execute the installation using Kustomize.

## Install K3S
```bash
sudo curl -sfL https://get.k3s.io | sudo sh -s - --disable traefik
```

Wait a minute for it to start, then verify
```bash
sudo k3s kubectl get nodes
ls /etc/rancher/k3s
```

### Configure kubectl Access

1. **Create standard kubectl config location:**
```bash
mkdir -p ~/.kube
```

2. **Copy K3s config to kubectl location:**
```bash
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

3. **Set correct ownership:**
```bash
sudo chown $USER:$USER ~/.kube/config
```

4. **Set KUBECONFIG environment variable:**
```bash
export KUBECONFIG=~/.kube/config
```

## Clone Repository

Before proceeding with the deployment, clone this repository to your local environment. This provides access to all configuration files needed for installing MinIO, MongoDB, RabbitMQ, and other required components.

```bash
git clone https://github.com/kerberos-io/deployment
cd deployment
```

## Dependencies

When deploying the Kerberos stack, several dependencies are essential: storage, database (MongoDB), and message broker (RabbitMQ) for asynchronous operations. These components must be installed prior to setting up the Agents, Factory, Vault, and Hub.

Unlike MicroK8s with its built-in addons, K3S takes a minimalist approach and comes with only essential components pre-installed. However, K3S includes CoreDNS for service discovery and a local-path storage provisioner by default, which covers most basic needs. Below are the key components and their status in K3S:

### Built-in Components (Already Available)

**DNS (CoreDNS):** Already enabled by default in K3S. No action required.

**Storage (local-path provisioner):** K3S includes a local-path storage provisioner by default. The storage class is named `local-path`.

To verify the default storage class:

```bash
kubectl get storageclass
```

You should see:

```bash
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  5m
```

### Optional Components

**Kubernetes Dashboard:** If you want a web UI for managing your cluster, install the Kubernetes Dashboard:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

**NVIDIA GPU Support:** If you have NVIDIA GPUs and need GPU acceleration, install the NVIDIA GPU Operator:

```bash
# Add NVIDIA Helm repository
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# Install NVIDIA GPU Operator
helm install --wait --generate-name \
  -n gpu-operator --create-namespace \
  nvidia/gpu-operator
```

You can verify the status of your cluster components with:

```bash
kubectl get po -w -A
```

### MinIO Object Storage

MinIO is a high-performance, distributed object storage system that is compatible with Amazon S3. It is designed to handle large-scale data storage and retrieval, making it ideal for modern cloud-native applications.

MinIO will store recordings from the Kerberos Agents. These recordings are crucial for surveillance and monitoring purposes, and MinIO ensures that data is stored securely and accessed efficiently.

```bash
git clone --depth 1 --branch v6.0.4 https://github.com/minio/operator.git
kubectl apply -k operator/
```

View the minio operator status with:

```bash
kubectl get po -w -A
```

Next we'll create a tenant. We need to update the storage class in the MinIO tenant configuration to use K3S's default `local-path` storage class:

```bash
sed -i 's/openebs-hostpath/local-path/g' ./base/minio/minio-tenant-base.yaml
kubectl apply -f ./base/minio/minio-tenant-base.yaml
```

Wait for the MinIO tenant pod to be fully ready (this is important to avoid "container not found" errors):

```bash
kubectl wait --for=condition=ready pod/myminio-pool-0-0 -n minio-tenant --timeout=300s
```

You can optionally view the minio tenant status with:

```bash
kubectl get po -n minio-tenant
```

You should see the `myminio` tenant running:

```bash
NAME               READY   STATUS    RESTARTS   AGE
minio-tenant   myminio-pool-0-0       2/2     Running   0       60s
```

Now we create a bucket in the minio tenant using `kubectl exec`.

```bash
# Creates alias myminio
kubectl exec -n minio-tenant myminio-pool-0-0 -c minio -- mc alias set myminio http://localhost:9000 minio minio123 --insecure
# Creates bucket mybucket
kubectl exec -n minio-tenant myminio-pool-0-0 -c minio -- mc mb myminio/mybucket --insecure
```

The expected output should resemble the following:

```bash
Added `myminio` successfully.
Bucket created successfully `myminio/mybucket`.
```

**Note:** If the bucket already exists, you'll see an error message saying "you already own it" - this is normal and means the bucket was created successfully in a previous run. You can verify the bucket exists with:

```bash
kubectl exec -n minio-tenant myminio-pool-0-0 -c minio -- mc ls myminio/ --insecure
```

#### Optional: Install MinIO Client Locally

If you prefer to manage MinIO from your host machine instead of using `kubectl exec`, you can install the MinIO client.

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc
chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/
```

Then expose the minio service and manage buckets directly:

```bash
kubectl port-forward svc/myminio-hl 9000 -n minio-tenant &
mc alias set myminio http://localhost:9000 minio minio123 --insecure
mc mb myminio/mybucket --insecure
pkill -f "port-forward"
```

The expected output should resemble the following:

```bash
user@k3s:~/deployment# mc mb myminio/mybucket --insecure
Handling connection for 9000
Bucket created successfully `myminio/mybucket`.
```

#### Access MinIO Console

To access the MinIO console UI, use kubectl port-forward:

```bash
kubectl port-forward svc/myminio-console -n minio-tenant 8080:9090 &
```

Then open your browser and navigate to `localhost:8080`. Use the credentials specified in the `minio-tenant-base.yaml` configuration file to log in. Once logged in, you can verify the bucket `mybucket` was created successfully.

Alternatively, if you need to access the console from a remote machine, you can use a reverse tunnel:

```bash
kubectl port-forward svc/myminio-console -n minio-tenant 8080:9090
ssh -L 8080:localhost:8080 youruser@x.x.x.x
```

## Kustomize Deployment

Kustomize provides a template-free way to customize Kubernetes configurations. Instead of maintaining multiple YAML files, Kustomize uses the concept of `bases` and `overlays`, allowing you to customize the base installation with environment-specific settings. This approach lets you deploy all Kerberos components (Agent, Factory, Vault, Hub) with a single command.

### Prerequisites

Before deploying with Kustomize, you need to configure two key values in the K3S overlay:

1. **IP Address**: The IP address of your K3S node (used for external access to services)
2. **Storage Path**: Directory path on your host for persistent storage

**Find your K3S node IP address:**

```bash
# Get your primary network interface IP (usually what you want)
hostname -I | awk '{print $1}'

# Or use ip command for more details
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
```

**Choose your storage path:**

```bash
# Example: Use a dedicated storage directory
STORAGE_PATH="/media/storage"

# Create it if it doesn't exist
sudo mkdir -p $STORAGE_PATH
```

### Configure K3S Overlay

The K3S overlay is located at `overlays/k3s/kustomization.yaml`. You need to update it with your IP address and storage path.

**Step 1: Set your configuration variables**

```bash
# Replace with your actual values
YOUR_IP="192.168.1.100"           # Your K3S node IP
YOUR_STORAGE="/media/storage"      # Your storage path
```

**Step 2: Update IP addresses in the overlay**

The following services need to be accessible via your node IP:
- Hub API and Frontend
- MQTT broker
- TURN server (for WebRTC)

```bash
# Update Hub API URL
sed -i "s|url: \".*:32081\"|url: \"${YOUR_IP}:32081\"|g" overlays/k3s/kustomization.yaml

# Update MQTT host
sed -i "s|host: \".*\"|host: \"${YOUR_IP}\"|g" overlays/k3s/kustomization.yaml

# Update TURN server host
sed -i "s|host: \"turn:.*:8443\"|host: \"turn:${YOUR_IP}:8443\"|g" overlays/k3s/kustomization.yaml
```

**Step 3: Update storage path**

K3S uses the `local-path` provisioner, but we also create a custom `ssd-hostpath` storage class for specific workloads:

```bash
# Update storage path in the overlay
sed -i "s|value: /media/Storage|value: ${YOUR_STORAGE}|g" overlays/k3s/kustomization.yaml
```

**Step 4: Verify your changes**

```bash
# Check that your IP and storage path were updated correctly
grep -A 2 "url:" overlays/k3s/kustomization.yaml
grep -A 2 "pvDir" overlays/k3s/kustomization.yaml
```

### Deploy with Kustomize

Once your overlay is configured, deploy the entire Kerberos stack. We use a two-step approach to avoid CRD timing issues:

**Step 1: Generate and apply all resources (including CRDs)**

```bash
kubectl kustomize overlays/k3s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -
```

**Step 2: Wait for CRDs to be established, then apply again**

```bash
# Wait for the ServiceMonitor CRD to be fully established
kubectl wait --for condition=established --timeout=60s crd/servicemonitors.monitoring.coreos.com

# Apply again to create ServiceMonitor resources
kubectl kustomize overlays/k3s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -
```

You should see resources being created:

```bash
namespace/kerberos-agent created
namespace/kerberos-factory created
namespace/kerberos-hub created
namespace/kerberos-vault created
namespace/minio-tenant unchanged
namespace/mongodb created
namespace/rabbitmq created
namespace/vernemq created
...
servicemonitor.monitoring.coreos.com/hub-metrics-servicemonitor created
```

**Monitor the deployment:**

```bash
# Watch all pods across namespaces
kubectl get po -w -A

# Or check specific namespace
kubectl get po -n kerberos-hub
kubectl get po -n kerberos-vault
kubectl get po -n kerberos-factory
```

**Wait for all pods to be ready (this may take 5-10 minutes):**

```bash
# Check if all pods are running
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
```

If the above command returns empty, all pods are running successfully.

### Verify Installation

Once all pods are running, you can access the services:

- **Kerberos Hub**: `http://${YOUR_IP}:32080`
- **Hub API**: `http://${YOUR_IP}:32081`
- **MQTT**: `ws://${YOUR_IP}:31080`

Continue with the [`configuration tutorial`](./README.configure.md) to configure and integrate the various components.

### Update Deployment

If you need to update the configuration:

```bash
# Apply changes
kubectl kustomize overlays/k3s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -
```

### Remove Deployment

To completely remove the Kerberos stack:

```bash
kubectl kustomize overlays/k3s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl delete -f -
```

## Install TURN Server

If installed and configured correctly, you should be able to access the various user interfaces and view live streams. However, to access high-definition live video, you need to install and configure a TURN server (such as coturn) for WebRTC NAT traversal.

```bash
sudo apt-get install -y coturn
```

After installing, clear the contents of the `/etc/turnserver.conf` configuration file.

```bash
sudo nano /etc/turnserver.conf
```

Add following configuration and save the `turnserver.conf` file. Make sure to replace `<ip_address>` with the host IP address.

```conf
listening-port=8443
relay-ip=<ip_address>
fingerprint
lt-cred-mech
user=username1:password1
syslog
```

Enable coturn on startup

```bash
sudo systemctl enable coturn
sudo systemctl restart coturn
```

## Custom Layout

Once the installation is complete, you can customize the Hub user interface with your own branding. A persistent volume claim (PVC) has been created and attached to the `hub-frontend` pod. To locate the persistent volume, navigate to your specified storage path. The volume will have a name starting with `kerberos-hub-custom-layout-claim-pvc`.

The PVC exists in TWO places simultaneously:

1. Physical location on the host (K3s node): `/var/lib/rancher/k3s/storage/pvc-9455ccfb-6cd6-4b64-b149-e98ccdc83d42_kerberos-hub_custom-layout-claim/`
2. Mounted location inside the container: `/usr/share/nginx/html/assets/custom/`

How the mount works:

Looking at your deployment config (line 300-306 in kerberos-hub-values.yaml):

```yaml
volumeMounts:
  - name: custom-layout
      mountPath: /usr/share/nginx/html/assets/custom  # ← Inside the container
volumes:
  - name: custom-layout
    persistentVolumeClaim:
      claimName: custom-layout-claim  # ← Points to the PVC

This tells Kubernetes: "Take the PVC storage and make it appear at /usr/share/nginx/html/assets/custom/ inside the container"
```

To copy custom branding files to the hub-frontend pod, run the following command from the deployment directory:

```bash
# Copy custom layout files to the hub-frontend pod
kubectl cp ./base/volume/. kerberos-hub/$(kubectl get pod -n kerberos-hub -l app=hub-frontend -o jsonpath='{.items[0].metadata.name}'):/usr/share/nginx/html/assets/custom/
```

Verify the files were copied successfully:

```bash
kubectl exec -n kerberos-hub $(kubectl get pod -n kerberos-hub -l app=hub-frontend -o jsonpath='{.items[0].metadata.name}') -- ls -la /usr/share/nginx/html/assets/custom/
```

Once the files are copied, you should see the CSS override on the Hub landing page.

## Access and Configuration

Once all pods are running, you can access the Kerberos services through NodePort services on your K3S node IP address.

### Service URLs

Replace `${YOUR_IP}` with your K3S node IP (e.g., `192.168.1.201`):

| Service | URL | Purpose |
|---------|-----|---------|
| **Kerberos Hub** | `http://${YOUR_IP}:32080` | Main web interface for managing cameras and viewing recordings |
| **Hub API** | `http://${YOUR_IP}:32081` | REST API for Hub |
| **Kerberos Vault** | `http://${YOUR_IP}:30080` | Storage and media management interface |
| **Kerberos Factory** | `http://${YOUR_IP}:30079` | Agent configuration and deployment |
| **MQTT Broker** | `ws://${YOUR_IP}:31080` | WebSocket MQTT for agents |
| **MQTT Broker (TCP)** | `tcp://${YOUR_IP}:31883` | TCP MQTT for agents |

### Default Credentials

**Kerberos Vault:**
- Username: `root`
- Password: `kerberos`

**Kerberos Hub:**
- Username: `example-user`
- Password: `example-password`
- (Application user: `example-application` / `example-password`)

**MinIO Console:**
- Access Key: `minio`
- Secret Key: `minio123`
- Console URL: Use port-forward or see MinIO section above

**MongoDB:**
- Username: `root`
- Password: `yourpassword` (as configured in kustomization.yaml)

**RabbitMQ:**
- Username: `yourusername`
- Password: `yourpassword` (as configured in kustomization.yaml)

### Initial Configuration

After accessing the services, you need to configure the system to make it operational. Follow these steps:

#### 1. Configure Vault

Access Kerberos Vault at `http://${YOUR_IP}:30080` and log in with the credentials above.

**Add Storage Provider (MinIO):**
1. Navigate to `Storage Providers` menu
2. Click `+ Add Storage Provider`
3. Configure MinIO:
   - **Enabled:** `true`
   - **Provider name:** `minio`
   - **Bucket name:** `mybucket`
   - **Region:** `na`
   - **Hostname:** `myminio-hl.minio-tenant:9000`
   - **Access key:** `minio`
   - **Secret key:** `minio123`
4. Click `Verify` to test the connection
5. Click `Add Storage Provider` to save

**Add Integration (RabbitMQ):**
1. Navigate to `Integrations` menu
2. Click `+ Add Integration`
3. Configure RabbitMQ:
   - **Enabled:** `true`
   - **Integration name:** `rabbitmq`
   - **Broker:** `rabbitmq.rabbitmq:5672`
   - **Exchange:** (leave empty)
   - **Queue:** `data-filtering`
   - **Username:** `yourusername`
   - **Password:** `yourpassword`
4. Click `Verify` to test the connection
5. Click `Add Integration` to save

**Create Account:**
1. Navigate to `Accounts` menu
2. Click `+ Add Account`
3. Configure account:
   - **Enabled:** `true`
   - **Account name:** `myaccount`
   - **Main provider:** `minio`
   - **Day limit:** `30`
   - **Integration:** `rabbitmq`
   - **Directory:** `*`
   - **Access key:** Generate or use: `XJoi2@bgSOvOYBy#`
   - **Secret key:** Generate or use: `OGGqat4lXRpL@9XBYc8FUaId@5`
4. Click `Add Account` to save

> **Security Note:** The credentials shown here are examples. In production, generate strong, unique credentials for all services.

#### 2. Configure Hub

Access Kerberos Hub at `http://${YOUR_IP}:32080` and complete the initial setup wizard to:
- Create admin account
- Configure storage connection to Vault
- Set up camera integrations

#### 3. Connect Agents

The deployed agents (camera1-agent, camera2-agent, etc.) are pre-configured to connect to the MQTT broker and Vault using the IP address in your kustomization.yaml.

To configure cameras:
1. Access Hub at `http://${YOUR_IP}:32080`
2. Navigate to camera management
3. Configure each agent with camera stream URLs

For detailed configuration instructions, refer to the [configuration tutorial](./README.configure.md).

## Cleanup

### Remove Kerberos Only

If you want to remove only the Kerberos stack while keeping K3S running:

```bash
# Remove all Kerberos resources
kubectl kustomize overlays/k3s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl delete -f -
```

This will remove all Kerberos namespaces and resources but keep K3S and other workloads intact.

Verify the cleanup:

```bash
# Check that Kerberos namespaces are gone
kubectl get namespaces | grep -E "kerberos|minio|mongodb|rabbitmq|vernemq"

# Check all remaining pods
kubectl get po -A
```

### Remove MinIO Operator

If you also want to remove the MinIO operator:

```bash
# Remove MinIO tenant first
kubectl delete -f ./base/minio/minio-tenant-base.yaml

# Remove MinIO operator
kubectl delete -k operator/
```

### Complete K3S Uninstall

If you want to completely remove K3S from your system:

```bash
# Uninstall K3S (this removes everything)
/usr/local/bin/k3s-uninstall.sh
```

**Warning:** This will remove K3S and ALL workloads running on it, not just Kerberos.

After uninstalling K3S, you may want to clean up storage:

```bash
# Remove K3S data directory
sudo rm -rf /var/lib/rancher/k3s

# Optionally remove your storage directory (adjust path if different)
sudo rm -rf /media/storage
```

Verify K3S is completely removed:

```bash
# This should fail with "command not found"
kubectl get nodes
```
