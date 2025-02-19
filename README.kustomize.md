# Deployment on Microk8s with Kustomize

⏱️ **Time:** installation within 25min

💻 **Environment:** tested on Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS

[<img src="https://github.com/kerberos-io/deployment/workflows/Deploy%20on%20Microk8s/badge.svg"/>](https://github.com/kerberos-io/deployment/actions/workflows/microk8s.yaml)

---

MicroK8s is a lightweight, fast, and secure Kubernetes distribution designed for developers and edge computing use cases. Developed by Canonical, MicroK8s is a minimalistic version of Kubernetes that can be installed with a single command and runs on various platforms, including Linux, macOS, and Windows. It is ideal for local development, CI/CD pipelines, IoT, and edge deployments due to its small footprint and ease of use. MicroK8s includes essential Kubernetes components and add-ons, such as DNS, storage, and the Kubernetes dashboard, making it a convenient choice for both beginners and experienced Kubernetes users.

In this tutorial, we will guide you through the installation of the complete stack, which includes the Agent, Factory, Vault, and Hub. This setup enables the storage of recordings from multiple cameras at the edge, facilitating local data processing and ensuring secure and efficient management of video streams. To simplify our efforts we will execute the installation using Kustomize.

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
   sudo snap install microk8s --classic --channel=1.32/stable
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

When deploying the various solutions, several dependencies are essential for storage, including a database (e.g., MongoDB) and a message broker (e.g., RabbitMQ) for asynchronous operations. These components must be installed prior to setting up the Agents, Factory, Vault, and Hub.

One of the significant advantages of MicroK8s is its built-in addons, which can be enabled with a single command. This feature eliminates the need for complex Helm charts or operators, thereby simplifying the setup process. In this guide, we will enable several common services, such as DNS, GPU support, and storage, to streamline the installation. However, if you prefer more control, you may opt to manually install these components using their respective Helm charts or operators.

```bash
microk8s enable dns
microk8s enable dashboard
microk8s enable nvidia
microk8s enable hostpath-storage
microk8s enable minio
```

You can verify the status of the enabled addons by running the following command:

```sh
microk8s.status
```

Or view the pod status with:

```bash
kubectl get po -w -A
```

### Storage class

By default, the `hostpath-storage` module uses a dedicated directory on your filesystem. In most cases, you may prefer to use a dedicated hard drive for storing your recordings, database, and other data. To achieve this, you can create your own storage class and assign it to the desired directory. Create a file `ssd-hostpath-sc.yaml` with following contents.

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ssd-hostpath
provisioner: microk8s.io/hostpath
reclaimPolicy: Delete
parameters:
  pvDir: /media/Storage
volumeBindingMode: WaitForFirstConsumer
```

Save the previously mentioned file `CTRL+O` and apply the Kubernetes resource.

```bash
kubectl apply -f ssd-hostpath-sc.yaml
```

You can verify the creation of the `storage class` using the following command. This `storage class` will be used in the subsequent installation steps, where each component, such as MongoDB, will create a `persistent volume` using the previously created `storage class`.

```bash
kubectl get sc -A
```

### Clone repository

Next, we will clone this repository to our local environment. This will allow us to execute the necessary configuration files for installing the Minio operator, MongoDB Helm chart, and other required components.

```bash
git clone https://github.com/kerberos-io/deployment
cd deployment
```

## Kustomize

In contrast to the detailed installation instructions, as mentioned here, an easier option to install is to use our Kustomize configure. This will allow you to specify and create your own overlays to install all the different components through a single command line.

```bash
kubectl kustomize overlays/microk8s/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -
```

Once the installation is running you should see something like following:

```bash
ubuntuvms@ubuntuvms:~/deployment$ kubectl kustomize overlays/microk8s/ --enable-helm  --load-restrictor LoadRestrictionsNone | kubectl apply -f -
namespace/kerberos-agent unchanged
namespace/kerberos-factory unchanged
namespace/kerberos-hub unchanged
namespace/kerberos-vault unchanged
namespace/minio-tenant unchanged
namespace/mongodb unchanged
namespace/rabbitmq unchanged
namespace/vernemq unchanged
customresourcedefinition.apiextensions.k8s.io/alertmanagerconfigs.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/alertmanagers.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/podmonitors.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/probes.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/prometheuses.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/prometheusrules.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/servicemonitors.monitoring.coreos.com configured
customresourcedefinition.apiextensions.k8s.io/thanosrulers.monitoring.coreos.com configured
...
```

Verify the installation using the `kubectl` command, it might take some time until all the Kubernetes pods are spinned up. Once everything is stable you should be able to access Factory, Vault and Hub using the node ip address their designated node ports.

Continue with the [`configuration tutorial`](./README.configure.md) to start with the configuration and integration of the various tools.

## Cleanup

If you consider to remove the complete stack you might just disable the Microk8s installation

```bash
microk8s reset
sudo snap remove microk8s
```

You can confirm all the workloads were removed from your system.

```bash
kubectl get po -w -A
```
