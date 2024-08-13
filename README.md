# Deployment

Deploying the Kerberos.io stack may initially appear to be a complex task due to its design for scalability from the outset. This entails the integration of several scalable components within a distributed deployment architecture. To streamline the installation process, we have established this repository to offer comprehensive guidance. Our objective is to incorporate as much automation as possible within this repository, thereby ensuring that the installation process is straightforward and user-friendly. At the same time, we remain committed to delivering a scalable and highly available video surveillance system.

## Architecture

As previously indicated, several integral components, including Object Storage, Database, and Message Brokers, are deployed and configured to ensure the proper functionality of Kerberos.io. The architecture diagrams below aims to provide a visual representation of these components and their interactions with one another depending the deploment; self-hosted or managed cloud deployment.

It is important to note that the ease of installation may vary depending on the chosen Kubernetes distribution and platform. For instance, distributions like Microk8s, which offer an addons feature, may simplify the installation process significantly. Managed Kubernetes services on platforms such as AWS, Azure, GCP, and others offer a range of supplementary services. These include, but are not limited to, cloud-based object storage, load balancers, persistent volumes, and additional resources that enhance the deployment experience. On the other hand running a self-hosted vanilla Kubernetes deployment will come with additinal work as it misses the out-of-the-box components from a managed deployment or the self-hosted Microk8s add-ons feature.

Given these differences, we have created specific architectural frameworks for self-hosted and cloud-based deployments. This approach ensures that each deployment is optimized for its environment, using the unique benefits and services of each platform. In the next section we discuss the different deployment strategies and installation processes.

## Self-hosted deployment

Self-hosted deployments are typically used for camera processing and edge storage. In this setup, Kerberos Agents are deployed and connected to cameras, with recordings stored in the Kerberos Vault. Additionally, you may want to create integrations, such as [data filtering](https://github.com/uug-ai/data-filtering), to ensure only relevant recordings are retained, or set up custom notifications to your first or third-party platforms. In this edge scenario, hardware is being deployed in the local network to handle the workloads; for example AMD64 or ARM64 processors.

![Self-hosted deployment](./assets/images/deployment-self-hosted.svg)

Follow the deployment guides for each Kubernetes distro:

- [Install Kerberos.io on Microk8s](/README.microk8s.md)
- [Install Kerberos.io on Kubernetes](/README.k8s.md)
- [Install Kerberos.io on Docker](/README.docker.md)

## Managed deployment

![Managed deployment](./assets/images/deployment-managed.svg)
