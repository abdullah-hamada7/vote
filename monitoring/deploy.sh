#!/bin/bash
set -e

echo "🚀 Deploying Monitoring Stack to k3s..."

# Add Prometheus Helm repo
echo "📦 Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "📁 Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack
echo "⚙️ Installing kube-prometheus-stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml \
  --wait

# Apply ServiceMonitors
echo "📊 Applying ServiceMonitors..."
kubectl apply -f servicemonitors.yaml

# Apply Alert Rules
echo "🔔 Applying Alert Rules..."
kubectl apply -f alerts.yaml

echo ""
echo "✅ Monitoring stack deployed successfully!"
echo ""
echo "📍 Access points:"
echo "  Grafana:      kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Prometheus:   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  AlertManager: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093"
echo ""
echo "🔑 Grafana credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "💡 Tip: Use NodePort services to access directly on k3s:"
echo "  Grafana:      http://localhost:30300"
echo "  Prometheus:   http://localhost:30900"
echo "  AlertManager: http://localhost:30093"
