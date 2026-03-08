#!/bin/bash

# set $cluster1 and $cluster2 kubeconfig
echo "Setting clusters kubeconfig $(pwd)/lab_clusters.sh"
source $(pwd)/lab_clusters.sh

function register_spire_entry() {
    local kind_config=$1; shift
    local spire_server=$1; shift
    local spire_agent=$1; shift
    local workload_name=$1; shift
    local trust_domain=$1; shift
    local federates_with_arg=$1; shift

    echo "-------------------------"
    echo "Registering node alias for ${spire_agent}"

    # Get the actual dynamically generated k8s_sat Agent SPIFFE ID
    local agent_id=$(kubectl exec -it --kubeconfig ${kind_config} \
       -n spire "${spire_server}-0" \
       -c "${spire_server}" \
       -- bin/spire-server agent list -socketPath /tmp/spire-server/private/api.sock \
       | grep "SPIFFE ID" | head -n 1 | awk '{print $4}' | tr -d '\r')

    echo "Found agent ID: ${agent_id}"

    echo "Registering workload: ${workload_name}"
    kubectl exec -it --kubeconfig ${kind_config} \
       -n spire "${spire_server}-0" \
       -c "${spire_server}" \
       -- bin/spire-server entry create \
           -socketPath /tmp/spire-server/private/api.sock \
           -spiffeID "spiffe://${trust_domain}/${workload_name}" \
           -parentID "${agent_id}" \
           -selector "k8s:sa:${workload_name}-service-account" \
           ${federates_with_arg}
    echo "-------------------------"
}

register_spire_entry $cluster1 "spire-server" "spire-agent" "server" "cluster1.com" "-federatesWith cluster2.com -federatesWith hub.com"
register_spire_entry $cluster2 "spire-server" "spire-agent" "client" "cluster2.com" "-federatesWith cluster1.com -federatesWith hub.com"
