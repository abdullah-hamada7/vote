#!/bin/bash
set -e

echo "Building images with correct tags..."
docker compose build

echo "Saving and importing images to K3s..."
IMAGES=("vote:latest" "result:latest" "worker:latest")

for img in "${IMAGES[@]}"; do
    echo "Exporting $img to K3s..."
    docker save "$img" | sudo k3s ctr images import -
done

echo "Restarting deployments..."
kubectl rollout restart deployment/vote-app-vote -n dev
kubectl rollout restart deployment/vote-app-result -n dev
kubectl rollout restart deployment/vote-app-worker -n dev
