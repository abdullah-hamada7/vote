#!/bin/bash

# Local Deploy Stage Test Script
# This script simulates the deploy stage from the CI/CD workflow for local testing

set -e  # Exit on error

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to 'dev' if not specified
REGISTRY="ghcr.io"
IMAGE_NAME="abdullah-hamada7/vote"
COMMIT_SHA="${2:-latest}"  # Use 'latest' if no commit SHA provided

echo "=========================================="
echo "Testing Deploy Stage Locally"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Commit SHA: $COMMIT_SHA"
echo "=========================================="

# Step 1: Verify prerequisites
echo ""
echo "[Step 1] Verifying prerequisites..."
if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm is not installed. Please install Helm v3.11.1 or later."
    exit 1
fi
echo "[OK] Helm version: $(helm version --short)"

if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] Kubectl is not installed. Please install kubectl v1.26.0 or later."
    exit 1
fi
echo "[OK] Kubectl version: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

# Check if k8s cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "[ERROR] Cannot connect to Kubernetes cluster. Make sure your cluster is running."
    exit 1
fi
echo "[OK] Kubernetes cluster is accessible"

# Step 2: Verify Helm chart exists
echo ""
echo "[Step 2] Verifying Helm chart..."
if [ ! -d "./k8s/charts/vote-app" ]; then
    echo "[ERROR] Helm chart not found at ./k8s/charts/vote-app"
    exit 1
fi
echo "[OK] Helm chart found"

# Check if values file exists
if [ ! -f "./k8s/charts/vote-app/values-$ENVIRONMENT.yaml" ]; then
    echo "[WARN] values-$ENVIRONMENT.yaml not found. Using default values.yaml"
    VALUES_FILE="./k8s/charts/vote-app/values.yaml"
else
    VALUES_FILE="./k8s/charts/vote-app/values-$ENVIRONMENT.yaml"
    echo "[OK] Using values file: $VALUES_FILE"
fi

# Step 3: Deploy with Helm (matching the workflow)
echo ""
echo "[Step 3] Deploying with Helm..."
helm upgrade --install vote-app ./k8s/charts/vote-app \
    --namespace "$ENVIRONMENT" \
    --create-namespace \
    --values "$VALUES_FILE" \
    --set vote.image="$REGISTRY/$IMAGE_NAME/vote:$COMMIT_SHA" \
    --set result.image="$REGISTRY/$IMAGE_NAME/result:$COMMIT_SHA" \
    --set worker.image="$REGISTRY/$IMAGE_NAME/worker:$COMMIT_SHA"

echo "[OK] Helm deployment completed"

# Step 4: Verify Deployments (matching the workflow)
echo ""
echo "[Step 4] Verifying deployments..."
echo "Verifying all deployments in $ENVIRONMENT..."
kubectl rollout status deployment/vote-app-vote -n "$ENVIRONMENT" --timeout=5m
kubectl rollout status deployment/vote-app-result -n "$ENVIRONMENT" --timeout=5m
kubectl rollout status deployment/vote-app-worker -n "$ENVIRONMENT" --timeout=5m

echo ""
echo "Verifying pods are running..."
kubectl get pods -n "$ENVIRONMENT" -l app=vote
kubectl get pods -n "$ENVIRONMENT" -l app=result
kubectl get pods -n "$ENVIRONMENT" -l app=worker

echo ""
echo "Checking service endpoints..."
kubectl get endpoints -n "$ENVIRONMENT"

echo "[OK] Deployment verification completed"

# Step 5: Smoke Tests (matching the workflow)
echo ""
echo "[Step 5] Running smoke tests..."
echo "Running smoke tests for $ENVIRONMENT environment..."

# Wait for services to be ready
sleep 10

# Test vote service (port-forward in background)
echo "Testing vote service..."
kubectl port-forward -n "$ENVIRONMENT" svc/vote 8080:80 &
PF_PID=$!
sleep 5

# Check if vote page loads
if curl -f http://localhost:8080/ > /dev/null 2>&1; then
    echo "[OK] Vote service is responding"
else
    echo "[ERROR] Vote service health check failed"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi
kill $PF_PID 2>/dev/null || true

# Test result service
echo "Testing result service..."
kubectl port-forward -n "$ENVIRONMENT" svc/result 8081:80 &
PF_PID=$!
sleep 5

if curl -f http://localhost:8081/ > /dev/null 2>&1; then
    echo "[OK] Result service is responding"
else
    echo "[ERROR] Result service health check failed"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi
kill $PF_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo "All smoke tests passed"
echo "=========================================="
echo ""
echo "Deployment Summary:"
echo "  - Environment: $ENVIRONMENT"
echo "  - Chart: ./k8s/charts/vote-app"
echo "  - Images: $REGISTRY/$IMAGE_NAME/*:$COMMIT_SHA"
echo ""
echo "Access your services:"
echo "  Vote:   kubectl port-forward -n $ENVIRONMENT svc/vote 8080:80"
echo "  Result: kubectl port-forward -n $ENVIRONMENT svc/result 8081:80"
echo "=========================================="
