# Cleanup Script

Script for removing Kubernetes resources from the cluster.

## Usage

```bash
./cleanup.sh [OPTIONS]
```

## Options

- `--all` - Clean all namespaces (dev, prod, monitoring)
- `--dev` - Clean dev namespace only
- `--prod` - Clean prod namespace only
- `--monitoring` - Clean monitoring namespace only
- `--help` - Show help message

## Examples

```bash
# Clean everything
./cleanup.sh --all

# Clean dev and monitoring only
./cleanup.sh --dev --monitoring

# Clean prod environment only
./cleanup.sh --prod
```

## What It Does

1. **Uninstalls Helm releases** in the specified namespaces
2. **Deletes namespaces** (which removes all resources)
3. **Shows summary** of remaining namespaces
4. **Requires confirmation** before proceeding

## Safety Features

- Confirmation prompt before deletion
- Checks if namespaces exist before attempting deletion
- Graceful handling of missing resources
- 60-second timeout for operations

## Redeployment

After cleanup, redeploy using:

**Dev Environment:**
```bash
./test-deploy-locally.sh dev latest
```

**Monitoring Stack:**
```bash
cd monitoring && ./deploy.sh
```

**Production:**
Use CI/CD pipeline or manual Helm deployment.
