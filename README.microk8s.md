# Edge deployment on microk8s

MicroK8s is a lightweight, fast, and secure Kubernetes distribution designed for developers and edge computing use cases. Developed by Canonical, MicroK8s is a minimalistic version of Kubernetes that can be installed with a single command and runs on various platforms, including Linux, macOS, and Windows. It is ideal for local development, CI/CD pipelines, IoT, and edge deployments due to its small footprint and ease of use. MicroK8s includes essential Kubernetes components and add-ons, such as DNS, storage, and the Kubernetes dashboard, making it a convenient choice for both beginners and experienced Kubernetes users.

In this tutorial, we will guide you through the installation of the Kerberos.io edge stack, which includes the Kerberos Agent, Kerberos Vault, and the Data Filtering Service. This setup enables the storage of recordings from multiple cameras at the edge, facilitating local data processing and ensuring secure and efficient management of video streams.

## Install Microk8s

To install MicroK8s on your system, follow these steps. First, ensure that you have `snapd` installed on your machine. If not, you can install it using the following command:

To install MicroK8s on your system, follow these steps.

1. **Ensure that you have `snapd` installed on your machine.**
   If not, you can install it using the following command:

   ```bash
   sudo apt update
   sudo apt install snapd
   ```

2. Install MicroK8s. Once snapd is installed, you can install MicroK8s with:

   ```bash
   sudo snap install microk8s --classic
   ```

3. Add your user to the microk8s group. This step is necessary to avoid using sudo for MicroK8s commands:

   ```bash
   sudo usermod -a -G microk8s $USER
   sudo chown -f -R $USER ~/.kube

   ```

4. Apply the new group membership. You need to re-enter your session for the group change to take effect:

   ```bash
   su - $USER
   ```

5. Check the status of MicroK8s. Ensure that MicroK8s is running correctly:

   ```bash
   microk8s status --wait-ready
   ```

6. Add an alias for kubectl as microk8s:

To simplify the usage of `kubectl` with MicroK8s, you can create an alias. This allows you to use the `kubectl` command without needing to prefix it with `microk8s.` every time. Add the following line to your shell configuration file (e.g., `.bashrc`, `.zshrc`):

```sh
alias kubectl='microk8s kubectl'
alias helm='microk8s helm'
```

or use the `snap` command:

```sh
sudo snap alias microk8s.kubectl kubectl
sudo snap alias microk8s.helm helm
```

For more detailed instructions and troubleshooting, please refer to the official MicroK8s documentation.

## Dependencies

When installing the Kerberos.io stack, several dependencies are required for storage, such as a database (e.g., MongoDB) and a message broker (e.g., RabbitMQ) for asynchronous behavior. We will install these components before setting up the Kerberos Agents and Kerberos Vault.

One of the key advantages of MicroK8s is its out-of-the-box addons, which can be enabled with a single command. This eliminates the need for complex Helm charts or operators, simplifying the setup process. We will enable some common services, such as DNS, GPU support, and storage, to streamline the installation.

```bash
microk8s enable dns
microk8s enable dashboard
microk8s enable gpu
microk8s enable hostpath-storage
```

You can verify the status of the enabled addons by running the following command:

```sh
microk8s.status
```

Or view the pod status with:

```bash
kubectl get po -w -A
```

### Object storage: MinIO

MinIO is a high-performance, distributed object storage system that is compatible with Amazon S3 cloud storage service. It is designed to handle large-scale data storage and retrieval, making it an ideal choice for modern cloud-native applications.

In the context of the Kerberos.io stack, MinIO will be used to store recordings from the Kerberos Agents. These recordings are crucial for surveillance and monitoring purposes, and having a reliable storage solution like MinIO ensures that the data is stored securely and can be accessed efficiently.

```bash
kubectl create namespace minio-tenant
```

```bash
kubectl apply -k github.com/minio/operator\?ref=v6.0.1
```

Next we'll create a tenant

```bash
sed -i 's/openebs-hostpath/microk8s-hostpath/g' ./minio-tenant-base.yaml
kubectl apply -f minio-tenant-base.yaml
```

We create a bucket in the minio tenant

```bash
kubectl port-forward svc/myminio-hl 9000 -n minio-tenant
```

You might need to install the minio client if not yet available.

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/
```

```bash
mc alias set myminio http://localhost:9000 minio minio123 --insecure
mc mb myminio/mybucket --insecure
```

or if not possible we will access the minio console using a reverse tunnel.

```bash
kubectl port-forward svc/myminio-console -n minio-tenant 8080:9090
ssh -L 8080:localhost:8080 youruser@x.x.x.x
```

To access the application, open your browser and navigate to `localhost:8080`. Use the credentials specified in the `minio-tenant-base.yaml` configuration file to log in. Once logged in, you can create a new bucket, such as `mybucket`, or choose a name of your preference.

### Database: MongoDB

When using Kerberos Vault, it will persist references to the recordings stored in your storage provider in a MongoDB database. As used before, we are using `helm` to install MongoDB in our Kubernetes cluster. Within the Kerberos Vault project we are using the latest official mongodb driver, so we support all major MongoDB versions (4.x, 5.x, 6.x, 7.x).

Have a look into the `./mongodb-values.yaml` file, you will find plenty of configurations for the MongoDB helm chart. To change the username and password of the MongoDB instance, go ahead and [find the attribute where](https://github.com/kerberos-io/vault/blob/master/kubernetes/mongodb/values.yaml#L148) you can change the root password. Please note that we are using the official [Bitnami Mongodb helm chart](https://github.com/bitnami/charts/tree/main/bitnami/mongodb), so please use their repository for more indepth configuration.

Next to that you might also consider a SaaS MongoDB deployment using MongoDB Atlas or using a managed cloud like AWS, GCP, Azure or Alibaba cloud. A managed service takes away a lot of management and maintenance from your side (backups, security, sharing, etc). If you do want to install MongoDB in your own cluster then please continue with this tutorial.

    helm repo add bitnami https://charts.bitnami.com/bitnami
    kubectl create namespace mongodb

Note: If you are installing a self-hosted Kubernetes cluster, we recommend using `openebs`. Therefore make sure to uncomment the `global`.`storageClass` attribute, and make sure it's using `microk8s-hostpath` instead.

    sed -i 's/openebs-hostpath/microk8s-hostpath/g' ./mongodb-values.yaml
    helm install mongodb -n mongodb bitnami/mongodb --values ./mongodb-values.yaml

Or after updating the `./mongodb-values.yaml` file again

    helm upgrade mongodb -n mongodb bitnami/mongodb --values ./mongodb-values.yaml

### Message broker: RabbitMQ

```bash
 kubectl create namespace rabbitmq
```

```bash
sed -i 's/openebs-hostpath/microk8s-hostpath/g' ./rabbitmq-values.yaml
helm install rabbitmq bitnami/rabbitmq -n rabbitmq -f rabbitmq-values.yaml
kubectl get po -A -w
```

```bash
helm upgrade rabbitmq bitnami/rabbitmq -n rabbitmq -f rabbitmq-values.yaml
```

```bash
helm del rabbitmq -n rabbitmq
```

### Kerberos Vault

#### Config Map

Kerberos Vault requires a configuration to connect to the MongoDB instance. To handle this `configmap` map is created in the `./mongodb/mongodb.config.yaml` file. However you might also use the environment variables within the `./kerberos-vault/deployment.yaml` file to configure the mongodb connection.

Modify the MongoDB credentials in the `./mongodb/mongodb.config.yaml`, and make sure they match the credentials of your MongoDB instance, as described above. There are two ways of configuring the mongodb connection, either you provide a `MONGODB_URI` or you specify the individual variables `MONGODB_USERNAME`, `MONGODB_PASSWORD`, etc.

As mentioned above a managed MongoDB is easier to setup and manage, for example for MongoDB Atlas, you will get a MongoDB URI in the form of `"mongodb+srv://xx:xx@kerberos-hub.xxx.mongodb.net/?retryWrites=true&w=majority&appName=xxx"`. By applying this value into the `MONGODB_URI` field, you will have setup your MongoDB connection successfully.

```yaml
- name: MONGODB_URI
  value: "mongodb+srv://xx:xx@kerberos-hub.xxx.mongodb.net/?retryWrites=true&w=majority&appName=xxx"
```

Once you applied this value, the other values like `MONGODB_USERNAME`, `MONGODB_PASSWORD` and others will be ignored. If you don't like the `MONGODB_URI` format you can still use the old way of defining the MongoDB connection by providing the different values.

```yaml
    - name: MONGODB_USERNAME
      value: "root"
    - name: MONGODB_PASSWORD
->    value: "yourmongodbpassword"
```

Create the config map in the `kerberos-vault` namespace.

```bash
kubectl create namespace kerberos-vault
```

Apply the mongodb configuration file, so the Kerberos Vault application knows how to connect to the MongoDB.

```bash
kubectl apply -f ./mongodb-config.yaml -n kerberos-vault
```

#### Deployment

To install the Kerberos Vault web app inside your cluster, simply execute below `kubectl` command. This will create the deployment for us with the necessary configurations, and exposed it on internal/external IP address, thanks to our `LoadBalancer` MetalLB or cloud provider.

```bash
kubectl apply -f ./kerberos-vault-deployment.yaml -n kerberos-vault
```

Verify if the pod is running

```bash
kubectl get po -w -A
```

#### Access the UI

If you have opted for the `NodePort` configuration, you can access the Kerberos Vault via the `http://localhost:30080` endpoint in your browser. For server installations without a GUI, consider setting up a reverse proxy to enable browser access from your local machine. Alternatively, you may utilize a `LoadBalancer` if one is available or if you are deploying on a managed Kubernetes service.

```bash
ssh -L 8080:localhost:30080 user@server-ip -p 22
```

#### Configure the Kerberos Vault

With the Kerberos Vault installed, we can proceed to configure the various components. Currently, this must be done through the Kerberos Vault UI, but we plan to make it configurable via environment variables, eliminating the need for manual UI configurations.

- Navigate to the `Storage Providers` menu and select the (+ Add Storage Provider) button. A modal will appear where you can input the required details. After entering the information, click the "Verify" button to ensure the configuration is valid. Once you receive a "Configuration is valid and working" message, click the "Add Storage Provider" button to complete the process.

  - Minio
    - Enabled: true
    - Provider name: minio
    - Bucket name: mybucket
    - Region: na
    - Hostname: myminio-hl.minio-tenant:9000
    - Access key: minio
    - Secret key: minio123

- Navigate to the `Integrations` menu and select the (+ Add Integration) button. A modal will appear where you can input the required details. After entering the information, click the "Verify" button to ensure the configuration is valid. Once you receive a "Configuration is valid and working" message, click the "Add Integration" button to complete the process.

  - RabbitMQ
    - Enabled: true
    - Integration name: rabbitmq
    - Broker: rabbitmq.rabbitmq:5672
    - Exchange:
    - Queue: data-filtering
    - Username: yourusername
    - Password: yourpassword

- Navigate to the `Accounts` menu and click the (+ Add Account) button. A modal will appear where you can input the required details. After entering the information, click the "Add Account" button to complete the process.

  - Enabled: true
  - Account name: myaccount
  - Main provider: minio
  - Day limit: 30
  - Integration: rabbitmq
  - Directory: \*
  - Access key: XJoi2@bgSOvOYBy#
  - Secret key: OGGqat4lXRpL@9XBYc8FUaId@5

### Create a Kerberos Agent

After deploying the Kerberos Vault and configuring the necessary services for storage, database, and integration, you can proceed to deploy the Kerberos Agent with the appropriate configuration. Review the `kerberos-agent-deployment.yaml` file and adjust the relevant settings, such as the RTSP URL, to ensure proper functionality. Please note that you can allow opt for the [Kerberos Factory](https://github.com/kerberos-io/factory/tree/master/kubernetes) which gives you a UI to manage the creation of Kerberos Agents.

```bash
kubectl apply -f kerberos-agent-deployment.yaml
```

Review the creation of the Kerberos Agent and review the logs of the container to validate the Kerberos Agent is able to connect to the IP camera, and if a recording is being created and transferred to the Kerberos Vault

```bash
kubectl get po -w -A
kubectl logs -f kerberos-agent...
```

To validate the Kerberos Vault and review any stored recordings, access the user interface at `http://localhost:30080` (after establishing the reverse tunnel).

### Optimized Data Filtering for Enhanced Bandwidth Efficiency and Relevance

Once your Kerberos Agents are properly connected and all recordings are stored in the Kerberos Vault, you may encounter additional challenges such as bandwidth limitations, storage constraints, and the need to efficiently locate relevant data. To accomplish this, we can configure an integration to filter the recordings, ensuring that only the relevant ones are retained.

Assuming all configurations are correctly set and all Kubernetes deployments are operational, you can apply the `data-filtering-deployment.yaml` deployment. This deployment will schedule a pod that listens to the configured integration in Kerberos Vault and runs a YOLOv8 model to evaluate the recordings and match them against specified conditions.

```bash
kubectl apply -f data-filtering-deployment.yaml
```

Each time a recording is stored in the Kerberos Vault, the `data-filtering` pod will receive a notification and execute the specified model (YOLOv8 by default). Based on the defined conditions, the `data-filtering` pod may forward the recording to a remote Kerberos Vault, trigger alerts, or send notifications.

Ensure that the `data-filtering` workload is actively running, receiving messages from the integration, and performing the necessary processing tasks.

```bash
kubectl get po -w -A
kubectl logs -f data...
```

### Add forwarding integration

We'll need to access the UI again to add the integration

```bash
ssh -L 8080:localhost:30080 user@server-ip -p 22
```

Go to the Kerberos Vault application in your browser and open the integration section, add a new integration.

- Add an integration

  - Kerberos Vault
    - Enabled: true
    - Integration name: rabbitmq
    - Broker: rabbitmq.rabbitmq:5672
    - Exchange:
    - Queue: data-filtering
    - Username: yourusername
    - Password: yourpassword
