#!/bin/bash
set -e

echo "=========================================="
echo "Cleaning Up Kubernetes Resources"
echo "=========================================="
echo ""

# Function to check if namespace exists
namespace_exists() {
    kubectl get namespace "$1" &> /dev/null
}

# Function to delete namespace with confirmation
delete_namespace() {
    local ns=$1
    if namespace_exists "$ns"; then
        echo "Deleting namespace: $ns"
        kubectl delete namespace "$ns" --timeout=60s
        echo "✓ Namespace $ns deleted"
    else
        echo "⊘ Namespace $ns does not exist, skipping"
    fi
}

# Parse command line arguments
CLEAN_ALL=false
CLEAN_DEV=false
CLEAN_PROD=false
CLEAN_MONITORING=false

if [ $# -eq 0 ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all           Clean all namespaces (dev, prod, monitoring)"
    echo "  --dev           Clean dev namespace only"
    echo "  --prod          Clean prod namespace only"
    echo "  --monitoring    Clean monitoring namespace only"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all                    # Clean everything"
    echo "  $0 --dev --monitoring       # Clean dev and monitoring"
    echo "  $0 --prod                   # Clean prod only"
    exit 0
fi

# Parse arguments
for arg in "$@"; do
    case $arg in
        --all)
            CLEAN_ALL=true
            ;;
        --dev)
            CLEAN_DEV=true
            ;;
        --prod)
            CLEAN_PROD=true
            ;;
        --monitoring)
            CLEAN_MONITORING=true
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all           Clean all namespaces (dev, prod, monitoring)"
            echo "  --dev           Clean dev namespace only"
            echo "  --prod          Clean prod namespace only"
            echo "  --monitoring    Clean monitoring namespace only"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set flags if --all is specified
if [ "$CLEAN_ALL" = true ]; then
    CLEAN_DEV=true
    CLEAN_PROD=true
    CLEAN_MONITORING=true
fi

echo "Cleanup Configuration:"
echo "  Dev Environment: $([ "$CLEAN_DEV" = true ] && echo "YES" || echo "NO")"
echo "  Prod Environment: $([ "$CLEAN_PROD" = true ] && echo "YES" || echo "NO")"
echo "  Monitoring Stack: $([ "$CLEAN_MONITORING" = true ] && echo "YES" || echo "NO")"
echo ""

# Confirmation prompt
read -p "Are you sure you want to proceed? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Clean dev namespace
if [ "$CLEAN_DEV" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cleaning Dev Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Uninstall Helm release first
    if helm list -n dev | grep -q vote-app; then
        echo "Uninstalling Helm release: vote-app"
        helm uninstall vote-app -n dev --timeout=60s
        echo "✓ Helm release uninstalled"
    else
        echo "⊘ No Helm release found in dev namespace"
    fi
    
    # Delete namespace
    delete_namespace "dev"
    echo ""
fi

# Clean prod namespace
if [ "$CLEAN_PROD" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cleaning Prod Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Uninstall Helm release first
    if helm list -n prod | grep -q vote-app; then
        echo "Uninstalling Helm release: vote-app"
        helm uninstall vote-app -n prod --timeout=60s
        echo "✓ Helm release uninstalled"
    else
        echo "⊘ No Helm release found in prod namespace"
    fi
    
    # Delete namespace
    delete_namespace "prod"
    echo ""
fi

# Clean monitoring namespace
if [ "$CLEAN_MONITORING" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cleaning Monitoring Stack"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Uninstall Helm release first
    if helm list -n monitoring | grep -q prometheus; then
        echo "Uninstalling Helm release: prometheus"
        helm uninstall prometheus -n monitoring --timeout=60s
        echo "✓ Helm release uninstalled"
    else
        echo "⊘ No Helm release found in monitoring namespace"
    fi
    
    # Delete namespace
    delete_namespace "monitoring"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cleanup Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show remaining namespaces
echo "Remaining namespaces:"
kubectl get namespaces | grep -E "dev|prod|monitoring" || echo "  None (all cleaned)"

echo ""
echo "✓ Cleanup completed successfully"
echo ""
echo "To redeploy:"
echo "  Dev:        ./test-deploy-locally.sh dev latest"
echo "  Prod:       Use CI/CD pipeline or manual Helm deployment"
echo "  Monitoring: cd monitoring && ./deploy.sh"
