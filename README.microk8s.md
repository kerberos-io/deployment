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
```

or use the `snap` command:

```sh
sudo snap alias microk8s.kubectl kubectl
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

To enable MinIO in your MicroK8s cluster, you can use the following command:

```sh
microk8s enable minio
```

This command will set up MinIO with default configurations, allowing you to start using it immediately. You can verify the status of the MinIO deployment by checking the pods:

```sh
kubectl get po -w -A
```

### Database: MongoDB

When using Kerberos Vault, it will persist references to the recordings stored in your storage provider in a MongoDB database. As used before, we are using `helm` to install MongoDB in our Kubernetes cluster. Within the Kerberos Vault project we are using the latest official mongodb driver, so we support all major MongoDB versions (4.x, 5.x, 6.x, 7.x).

Have a look into the `./mongodb-values.yaml` file, you will find plenty of configurations for the MongoDB helm chart. To change the username and password of the MongoDB instance, go ahead and [find the attribute where](https://github.com/kerberos-io/vault/blob/master/kubernetes/mongodb/values.yaml#L148) you can change the root password. Please note that we are using the official [Bitnami Mongodb helm chart](https://github.com/bitnami/charts/tree/main/bitnami/mongodb), so please use their repository for more indepth configuration.

Next to that you might also consider a SaaS MongoDB deployment using MongoDB Atlas or using a managed cloud like AWS, GCP, Azure or Alibaba cloud. A managed service takes away a lot of management and maintenance from your side (backups, security, sharing, etc). If you do want to install MongoDB in your own cluster then please continue with this tutorial.

    microk8s helm repo add bitnami https://charts.bitnami.com/bitnami
    kubectl create namespace mongodb

Note: If you are installing a self-hosted Kubernetes cluster, we recommend using `openebs`. Therefore make sure to uncomment the `global`.`storageClass` attribute, and make sure it's using `microk8s-hostpath` instead.

    sed -i '' 's/openebs-hostpath/microk8s-hostpath/g' ./mongodb-values.yaml
    microk8s helm install mongodb -n mongodb bitnami/mongodb --values ./mongodb-values.yaml

Or after updating the `./mongodb-values.yaml` file again

    microk8s helm upgrade mongodb -n mongodb bitnami/mongodb --values ./mongodb-values.yaml
