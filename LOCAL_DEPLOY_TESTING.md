# Testing the Deploy Stage Locally

This guide explains how to test the deploy stage of the CI/CD workflow locally.

## Prerequisites

- Helm v3.11.1 or later installed
- kubectl v1.26.0 or later installed
- Kubernetes cluster running (k3s or similar)
- Access to pull Docker images from `ghcr.io`

## Quick Start

Run the test script with default settings (dev environment, latest images):

```bash
./test-deploy-locally.sh
```

## Usage Options

### Test Different Environments

```bash
# Test dev environment (default)
./test-deploy-locally.sh dev

# Test prod environment
./test-deploy-locally.sh prod
```

### Test Specific Commit/Tag

```bash
# Test with specific commit SHA
./test-deploy-locally.sh dev abc1234

# Test with latest tag
./test-deploy-locally.sh dev latest
```

## What the Script Does

The script mirrors the **deploy** job from `.github/workflows/ci-cd.yml`:

1. **Verifies Prerequisites**
   - Checks Helm installation
   - Checks kubectl installation
   - Verifies Kubernetes cluster connectivity

2. **Validates Resources**
   - Confirms Helm chart exists at `./k8s/charts/vote-app`
   - Checks for environment-specific values file
   - Updates Helm dependencies (downloads Bitnami Redis and PostgreSQL charts)

3. **Deploys with Helm**

   ```bash
   helm upgrade --install vote-app ./k8s/charts/vote-app \
     --namespace <environment> \
     --create-namespace \
     --values ./k8s/charts/vote-app/values-<environment>.yaml \
     --set vote.image=ghcr.io/abdullah-hamada7/vote/vote:<sha> \
     --set result.image=ghcr.io/abdullah-hamada7/vote/result:<sha> \
     --set worker.image=ghcr.io/abdullah-hamada7/vote/worker:<sha>
   ```

   This single command deploys:
   - Redis (via Bitnami chart dependency)
   - PostgreSQL (via Bitnami chart dependency)
   - Vote, Result, and Worker services

4. **Verifies Deployments**
   - Checks rollout status for all services (vote, result, worker)
   - Lists running pods
   - Shows service endpoints

5. **Runs Smoke Tests**
   - Port-forwards vote service and tests HTTP response
   - Port-forwards result service and tests HTTP response

## Expected Output

A successful test run will show:

```text
==========================================
Testing Deploy Stage Locally
==========================================
Environment: dev
Commit SHA: latest
==========================================

📋 Step 1: Verifying prerequisites...
✅ Helm version: v3.11.1
✅ Kubectl version: v1.26.0
✅ Kubernetes cluster is accessible

📋 Step 2: Verifying Helm chart...
✅ Helm chart found
✅ Using values file: ./k8s/charts/vote-app/values-dev.yaml
Updating Helm dependencies...
✅ Dependencies updated

📋 Step 3: Deploying with Helm...
✅ Helm deployment completed

📋 Step 4: Verifying deployments...
✅ Deployment verification completed

📋 Step 5: Running smoke tests...
✅ Vote service is responding
✅ Result service is responding

==========================================
✅ All smoke tests passed!
==========================================
```

## Troubleshooting

### Helm/kubectl Not Found

Install the required tools:

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Cluster Not Accessible

Ensure your k3s cluster is running:

```bash
sudo systemctl status k3s
kubectl get nodes
```

### Image Pull Issues

Make sure you're authenticated to the GitHub Container Registry:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin
```

### Port Already in Use

If ports 8080 or 8081 are in use, kill the processes:

```bash
sudo lsof -ti:8080 | xargs kill -9
sudo lsof -ti:8081 | xargs kill -9
```

## Cleanup

To remove the deployed resources:

```bash
# Delete the dev environment
helm uninstall vote-app -n dev
kubectl delete namespace dev

# Delete the prod environment
helm uninstall vote-app -n prod
kubectl delete namespace prod
```

## Accessing Services After Testing

After successful deployment, access your services:

```bash
# Vote service
kubectl port-forward -n dev svc/vote 8080:80

# Result service
kubectl port-forward -n dev svc/result 8081:80

# View logs
kubectl logs -n dev -l app=vote
kubectl logs -n dev -l app=result
kubectl logs -n dev -l app=worker
```
