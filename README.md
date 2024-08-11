# Deployment

Deploying the Kerberos.io stack may initially appear to be a complex task due to its design for scalability from the outset. This entails the integration of several scalable components within a distributed deployment architecture. To streamline the installation process, we have established this repository to offer comprehensive guidance. Our objective is to incorporate as much automation as possible within this repository, thereby ensuring that the installation process is straightforward and user-friendly. At the same time, we remain committed to delivering a scalable and highly available video surveillance system.

## Architecture

As previously indicated, several integral components, including Object Storage, Database, and Message Brokers, are implemented to ensure the proper functionality of Kerberos.io. The architecture diagram below aims to provide a visual representation of these components and their interactions with one another.

It is important to note that the ease of installation may vary depending on the chosen Kubernetes distribution. For instance, distributions like Microk8s, which offer an addons feature, may simplify the installation process significantly. Managed Kubernetes services on platforms such as AWS, Azure, GCP, and others offer a range of supplementary services. These include, but are not limited to, cloud-based object storage, load balancers, persistent volumes, and additional resources that enhance the deployment experience.

In light of these variations, we have meticulously developed distinct architectural frameworks to clearly delineate between self-hosted deployments and those based in the cloud. This differentiation ensures that each deployment scenario is optimized for its respective environment, leveraging the unique advantages and services provided by each platform.

![Self-hosted deployment ](./assets/images/deployment-self-hosted.svg)

Follow the deployment guides for each Kubernetes distro:

- [Install Kerberos.io on Microk8s](/README.microk8s.md)
- [Install Kerberos.io on Kubernetes](/README.k8s.md)
