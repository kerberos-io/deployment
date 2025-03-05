# Configuration

After completing the installation using one of the provided methods, you can proceed with the configuration and setup of the various components. Depending on your deployment method, refer to the appropriate README for detailed instructions:

- [Docker](./README.docker.md)
- [Kubernetes](./README.kubernetes.md)
- [MicroK8S](./README.microk8s.md)
- [Kustomize](./README.kustomize.md)

## Access through ingress or NodePort

Taking into account your installation you should be able to access the different applications using their relative `Ingress` or `NodePort`. For example when following the [Kustomize](./README.kustomize.md) installation

## Login to Vault

Once you have access to the Vault user interface, you should be able to login with a username and password. You will [find the username and password here](https://github.com/kerberos-io/deployment/blob/main/kerberos-vault-deployment.yaml#L36-L39).

- Username: [**view username**](https://github.com/kerberos-io/deployment/blob/main/kerberos-vault-deployment.yaml#L36-L37)
- Password: [**view password**](https://github.com/kerberos-io/deployment/blob/main/kerberos-vault-deployment.yaml#L38-L39)

### Configure the Vault

With the Vault installed, we can proceed to configure the various components. Currently, this must be done through the Vault UI, but we plan to make it configurable via environment variables, eliminating the need for manual UI configurations.

![Configure Vault](./assets/images/configure-vault.gif)

- Navigate to the `Storage Providers` menu and select the (+ Add Storage Provider) button. A modal will appear where you can input the required details. After entering the information, click the "Verify" button to ensure the configuration is valid. Once you receive a "Configuration is valid and working" message, click the "Add Storage Provider" button to complete the process. **_(!You are advised to generate more complex access and secret key for Minio, this is just for demo purposes, do not use this in production)_**

  - Minio
    - Enabled: true
    - Provider name: minio
    - Bucket name: mybucket
    - Region: na
    - Hostname: myminio-hl.minio-tenant:9000
    - Access key: minio
    - Secret key: minio123

- Navigate to the `Integrations` menu and select the (+ Add Integration) button. A modal will appear where you can input the required details. After entering the information, click the "Verify" button to ensure the configuration is valid. Once you receive a "Configuration is valid and working" message, click the "Add Integration" button to complete the process. **_(!You are advised to generate more complex username and password for RabbitMQ, this is just for demo purposes, do not use this in production)_**

  - RabbitMQ
    - Enabled: true
    - Integration name: rabbitmq
    - Broker: rabbitmq.rabbitmq:5672
    - Exchange: <empty>
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
  - Access key: XJoi2@bgSOvOYBy# (or generate new keys, but don't forget to update them in the next steps)
  - Secret key: OGGqat4lXRpL@9XBYc8FUaId@5 (or generate new keys, but don't forget to update them in the next steps)
