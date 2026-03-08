# Spire Federation using Kind Clusters

[![Release Actions status](https://github.com/nishantapatil3/spire-federation-kind/workflows/Release/badge.svg)](https://github.com/nishantapatil3/spire-federation-kind/actions/workflows/release.yml)

> [!NOTE]
> Check out this Cisco Blog for an Intro on: [SPIFFE/SPIRE Federation on Kind clusters](https://outshift.cisco.com/blog/spire-federation-kind)

Spire Federation provides zero-trust security for workloads in Kubernetes clusters and is widely adopted by cloud service providers.

In this example, we will create two kind clusters and set them up with trust domains `cluster1.com` and `cluster2.com`.

## Federation Example

### Requirements

- A 64-bit Linux or macOS environment
- [kind](https://kind.sigs.k8s.io/) to deploy Kubernetes clusters
- [kubectl](https://kubernetes.io/docs/tasks/tools/) to execute commands
- [Docker](https://docs.docker.com/get-docker/) installed
- [helm](https://helm.sh/) charts to manage applications
- [Go](https://golang.org/dl/) 1.14.4 or higher

### 1. Build and Prepare Images

Build the Docker images for the broker and quotes service, then load them into the kind clusters.

```bash
./1-build.sh
# Load images into kind nodes (required for local development)
kind load docker-image ghcr.io/nishantapatil3/broker-webapp:latest --name kind-2
kind load docker-image ghcr.io/nishantapatil3/stock-quotes-service:latest --name kind-1
```

### 2. Create Clusters

```bash
kind create cluster --name kind-1
kind create cluster --name kind-2

mkdir -p $PWD/kubeconfigs
kind get kubeconfig --name=kind-1 > $PWD/kubeconfigs/kind-1.kubeconfig
kind get kubeconfig --name=kind-2 > $PWD/kubeconfigs/kind-2.kubeconfig

# Load cluster identifiers into your environment
source lab_clusters.sh
```

### 3. Deploy MetalLB (Networking)

MetalLB allows the two clusters to reach each other via External IPs on the Docker bridge network.

> [!IMPORTANT]
> By default, `kind` typically uses the `172.18.0.0/16` subnet. Check yours with `docker network inspect kind`.
> If your subnet is different, update the IP ranges in `helm/metallb-system/ipaddresspool*.yaml` before applying.

```bash
helm repo add metallb https://metallb.github.io/metallb

export KUBECONFIG=$cluster1
kubectl create ns metallb-system
helm install metallb metallb/metallb --namespace metallb-system

export KUBECONFIG=$cluster2
kubectl create ns metallb-system
helm install metallb metallb/metallb --namespace metallb-system
unset KUBECONFIG

# Apply IP pools (Adjust IPs in these files if your kind subnet isn't 172.18.x.x)
kubectl apply -f helm/metallb-system/ipaddresspool1.yaml --kubeconfig $cluster1
kubectl apply -f helm/metallb-system/ipaddresspool2.yaml --kubeconfig $cluster2
```

### 4. Deploy SPIRE Infrastructure

Deploy the SPIRE server and agent. Replace the `address` fields below with your actual MetalLB LoadBalancer IPs if they differ from the defaults.

```bash
# Deploy to Cluster 1
helm template helm/spire --set trustDomain=cluster1.com \
  --set "federatesWith[0].trustDomain=cluster2.com" \
  --set "federatesWith[0].address=172.18.254.1" \
  --set "federatesWith[0].port=8443" | kubectl apply --kubeconfig $cluster1 -f -

# Deploy to Cluster 2
helm template helm/spire --set trustDomain=cluster2.com \
  --set "federatesWith[0].trustDomain=cluster1.com" \
  --set "federatesWith[0].address=172.18.255.1" \
  --set "federatesWith[0].port=8443" | kubectl apply --kubeconfig $cluster2 -f -
```

### 5. Bootstrap and Register

Exchange trust bundles between clusters and register the workloads.

```bash
./2-bootstrap.sh
./3-register.sh
```

### 6. Deploy Workloads

Apply the server (Cluster 1) and client (Cluster 2).

```bash
# Cluster 1: Backend
kubectl apply -f helm/server.yaml --kubeconfig $cluster1

# Cluster 2: Frontend
# Note: Ensure QUOTES_SERVICE_HOST in helm/client.yaml matches the backend External IP (172.18.255.2)
kubectl apply -f helm/client.yaml --kubeconfig $cluster2
```

## Troubleshooting & Reset

### Page Keeps Loading / "Quotes service unavailable"

- **Verify IPs:** Check `kubectl get svc -A` in both clusters. Ensure the `EXTERNAL-IP` matches what you configured in `helm/spire` and `helm/client.yaml`.
- **SPIFFE Identities:** If pods can't fetch SVIDs, check logs: `kubectl logs -l app=broker-webapp --kubeconfig $cluster2`.
- **Hard Reset:** If identities are out of sync (e.g., after a node restart), run this to wipe the cached SPIRE state:

  ```bash
  # Delete SPIRE components
  kubectl delete statefulset spire-server -n spire --kubeconfig $cluster1
  kubectl delete statefulset spire-server -n spire --kubeconfig $cluster2
  # Clear host-path data on the kind nodes
  docker exec kind-1-control-plane rm -rf /var/spire-data /run/spire/sockets
  docker exec kind-2-control-plane rm -rf /var/spire-data /run/spire/sockets
  # Now re-deploy from Step 4
  ```

## Verification

Port-forward the client pod to your localhost:

```bash
kubectl port-forward svc/broker-webapp 8080:8080 --kubeconfig $cluster2
```

Open [http://localhost:8080/quotes](http://localhost:8080/quotes). You should see a live grid of stock quotes securely fetched cross-cluster via federated SPIFFE identities.

![stockbroker-webpage](./images/stockbroker-webpage.png)
