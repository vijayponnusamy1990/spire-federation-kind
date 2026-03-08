#!/bin/bash

# Stop on error
set -e

echo "Tearing down SPIRE Federation Demo..."

# Delete kind clusters
echo "Deleting kind clusters..."
kind delete cluster --name kind-1
kind delete cluster --name kind-2

# Remove kubeconfigs directory
echo "Removing kubeconfigs/ directory..."
rm -rf kubeconfigs/

echo "----------------------------------------"
echo "Teardown complete! All resources removed."
echo "----------------------------------------"
