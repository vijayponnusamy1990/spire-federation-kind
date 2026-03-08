#!/bin/bash

# Load environment
source lab_clusters.sh

echo "Bootstrapping Hub-Spoke Federation..."

# Helper to exchange bundles between a KIND cluster and the Hub container
# $1: kubeconfig of the kind cluster
# $2: trust domain of the kind cluster
function exchange_with_hub() {
    local cluster=$1
    local trust_domain=$2

    echo "--- Exchanging between $trust_domain and hub.com ---"

    # 1. Get Cluster Bundle -> Set on Hub
    echo "Exporting bundle from $trust_domain to Hub..."
    kubectl exec -n spire spire-server-0 --kubeconfig $cluster -c spire-server -- \
        bin/spire-server bundle show -socketPath /tmp/spire-server/private/api.sock -format spiffe | \
        docker exec -i spire-hub bin/spire-server bundle set -socketPath /tmp/spire-server/private/api.sock -format spiffe -id spiffe://$trust_domain

    # 2. Get Hub Bundle -> Set on Cluster
    echo "Exporting bundle from Hub to $trust_domain..."
    docker exec spire-hub bin/spire-server bundle show -socketPath /tmp/spire-server/private/api.sock -format spiffe | \
        kubectl exec -i -n spire spire-server-0 --kubeconfig $cluster -c spire-server -- \
        bin/spire-server bundle set -socketPath /tmp/spire-server/private/api.sock -format spiffe -id spiffe://hub.com
}

# Perform Hub-Spoke exchanges
exchange_with_hub $cluster1 cluster1.com
exchange_with_hub $cluster2 cluster2.com

# For the demo app to keep working, spokes still need each other's bundles if they haven't been exchanged recently.
# However, in a Hub-Spoke model, we might want to demonstrate spoke-to-spoke through the hub.
# But SPIRE MTLS currently needs the direct bundle.
echo "Ensuring Cluster 1 and Cluster 2 trust each other..."
./2-bootstrap.sh

echo "Hub-Spoke Federation Bootstrap Complete!"
