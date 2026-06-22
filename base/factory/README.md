# Factory — base manifests

This directory holds the raw Kubernetes manifests for **Factory**. Factory
is a web application that runs *inside* your cluster and uses the Kubernetes API to
deploy, configure and observe Agents (one Deployment + Service per camera).

> **Scope of this README.** At the top level of this repository Factory is normally
> installed through **Kustomize** (see [`overlays/`](../../overlays) and the
> [`README.kustomize.md`](../../README.kustomize.md)). This README documents the
> alternative: applying the manifests in this folder **directly with `kubectl`**,
> without Kustomize. Use it when you want to install only Factory, understand each
> object in isolation, or integrate these manifests into your own tooling.

## What gets deployed

| File | Kind | Purpose |
| ---- | ---- | ------- |
| [`kerberos-factory-deployment.yaml`](./kerberos-factory-deployment.yaml) | `Deployment` | The Factory web app/API (`uugai/factory`), container port `80`. |
| [`kerberos-factory-service.yaml`](./kerberos-factory-service.yaml) | `Service` | Exposes Factory on `NodePort` **30079** (a `LoadBalancer` variant is included, commented out). |
| [`kerberos-factory-clusterrole.yaml`](./kerberos-factory-clusterrole.yaml) | `ClusterRole` + `ClusterRoleBinding` | Grants the `default` ServiceAccount in `kerberos-factory` the API access Factory needs to manage Agents. |

The matching namespace (`kerberos-factory`) is defined one level up in
[`../namespaces/kerberos-factory.yaml`](../namespaces/kerberos-factory.yaml).

## Configuration (ConfigMap store + Kubernetes engine)

These manifests are configured to run Factory **without MongoDB**. Factory keeps its
own (global/template) configuration and delivers each Agent's configuration through
Kubernetes **ConfigMaps**, and schedules Agents with the **Kubernetes** engine. This
is controlled by two environment variables on the Deployment:

```yaml
- name: FACTORY_CONFIGURATION
  value: "configmap"      # store config in ConfigMaps (json | configmap | secret | mongodb)
- name: FACTORY_ENGINE
  value: "kubernetes"     # schedule agents as Deployments (kubernetes | docker | host)
```

On start-up Factory bootstraps two cluster ConfigMaps — `agent-global-config`
(settings every Agent inherits) and `agent-template-config` (the base used for new
Agents) — and creates a per-agent `<name>-config` ConfigMap for each Agent it
provisions. **This is why the ClusterRole includes `configmaps`** — without that
permission the bootstrap fails.

Other relevant environment variables:

| Variable | Default here | Meaning |
| -------- | ------------ | ------- |
| `KERBEROS_LOGIN_USERNAME` / `KERBEROS_LOGIN_PASSWORD` | `root` / `kerberos` | Factory UI login. **Change these for anything but a demo.** |
| `KERBEROS_AGENT_IMAGE` | `kerberos/agent:latest` | Image used when Factory creates an Agent. |
| `KERBEROS_AGENT_MEMORY_LIMIT` | `256Mi` | Default memory limit for created Agents. |
| `NAMESPACE` | `kerberos-factory` | Namespace Factory schedules Agents into. |
| `K8S_PROXY` | `http://localhost:80` | Internal proxy address Factory calls for the `/kubernetes` API. |

## Prerequisites

- A running Kubernetes cluster and a `kubectl` configured to reach it.
- Permission to create `ClusterRole`/`ClusterRoleBinding` (cluster-admin or equivalent).

## Deploy with `kubectl` (without Kustomize)

The manifest files do **not** hard-code a namespace (Kustomize injects it at the upper
level). When applying directly, target the namespace explicitly with `-n`.

```bash
# 1. Create the namespace (only needed if it does not exist yet)
kubectl apply -f ../namespaces/kerberos-factory.yaml

# 2. Create the RBAC. The ClusterRole/ClusterRoleBinding are cluster-scoped;
#    the binding's subject already references the kerberos-factory namespace.
kubectl apply -f ./kerberos-factory-clusterrole.yaml

# 3. Deploy Factory and its service into the namespace
kubectl apply -n kerberos-factory -f ./kerberos-factory-deployment.yaml
kubectl apply -n kerberos-factory -f ./kerberos-factory-service.yaml
```

Or apply the whole folder at once (RBAC is cluster-scoped, the rest lands in the
namespace):

```bash
kubectl apply -f ../namespaces/kerberos-factory.yaml
kubectl apply -n kerberos-factory -f ./
```

Verify the rollout:

```bash
kubectl get pods,svc -n kerberos-factory
kubectl rollout status deployment/factory -n kerberos-factory
kubectl logs -n kerberos-factory deploy/factory
```

You should see log lines confirming the global and template Agent ConfigMaps were
bootstrapped.

## Access the UI

With the `NodePort` service, Factory is reachable on port **30079** of any node:

```bash
# Example: open http://<node-ip>:30079
kubectl get nodes -o wide        # find a node IP

# Or port-forward without exposing a node port
kubectl port-forward -n kerberos-factory svc/factory-nodeport 8080:80
# then browse http://localhost:8080
```

Log in with the `KERBEROS_LOGIN_USERNAME` / `KERBEROS_LOGIN_PASSWORD` values above
(default `root` / `kerberos`).

To use a cloud `LoadBalancer` instead of a `NodePort`, uncomment the `factory-lb`
service at the bottom of [`kerberos-factory-service.yaml`](./kerberos-factory-service.yaml)
and comment out the `NodePort` service.

## Switching the configuration store

ConfigMap storage is recommended for a clean, database-free install, but Factory
supports other stores via `FACTORY_CONFIGURATION`:

- `configmap` *(default here)* — config in ConfigMaps, no MongoDB.
- `secret` — same as `configmap` but sensitive values are kept in Kubernetes Secrets
  (add `secrets` to the ClusterRole resources for this mode).
- `json` — config in local JSON files on the pod, no MongoDB.
- `mongodb` — legacy behaviour: Factory and Agents read config from MongoDB. For this
  you also need a reachable MongoDB and the corresponding `MONGODB_*` environment
  variables (e.g. via a `mongodb` ConfigMap mounted with `envFrom`).

See the [Configuration & engines documentation](https://github.com/uug-ai/factory)
for the full model.

## Uninstall

```bash
kubectl delete -n kerberos-factory -f ./kerberos-factory-service.yaml
kubectl delete -n kerberos-factory -f ./kerberos-factory-deployment.yaml
kubectl delete -f ./kerberos-factory-clusterrole.yaml
# Optionally remove the agent ConfigMaps Factory created and the namespace
kubectl delete configmap -n kerberos-factory agent-global-config agent-template-config --ignore-not-found
kubectl delete -f ../namespaces/kerberos-factory.yaml
```
