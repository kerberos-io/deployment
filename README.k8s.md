# Self-hosted deployment on Kubernetes

Within this tutorial we will install the Kerberos.io edge stack (Kerberos Agent, Kerberos Vault and the Data filtering service). This will allow us to store recordings from multiple cameras at the edge

### OpenEBS

Some of the services we'll leverage such as MongoDB or Minio require storage, to persist their data safely. In a managed Kubernetes cluster, the relevant cloud provider will allocate storage automatically for you, as you might expect this is not the case for a self-hosted cluster.

Therefore we will need to prepare some storage or persistent volume. To simplify this we can leverage the OpenEBS storage solution, which can automatically provision PV (Persistent volumes) for us.

Let us start with installing the OpenEBS operator. Please note that you might need to change the mount folder. Download the `openebs-operator.yaml`.

    wget https://openebs.github.io/charts/openebs-operator.yaml

Scroll to the bottom, until you hit the `StorageClass` section. Modify the `BasePath` value to the destination (external mount) you prefer.

    #Specify the location (directory) where
    # where PV(volume) data will be saved.
    # A sub-directory with pv-name will be
    # created. When the volume is deleted,
    # the PV sub-directory will be deleted.
    #Default value is /var/openebs/local
    - name: BasePath
      value: "/var/openebs/local/"

Once you are ok with the `BasePath` go ahead and apply the operator.

    kubectl apply -f openebs-operator.yaml

Once done it should start installing several resources in the `openebs` namespace. If all resources are created successfully we can launch the `helm install` for MongoDB.

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
