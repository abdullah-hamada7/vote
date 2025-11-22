# Monitoring Stack Setup

This directory contains the Prometheus + Grafana monitoring stack for the voting application.

## Quick Start

```bash
# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install with custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f values.yaml

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Default credentials
# Username: admin
# Password: prom-operator
```

## What's Included

- **Prometheus Operator**: Manages Prometheus instances
- **Grafana**: Visualization dashboards
- **AlertManager**: Alert management
- **ServiceMonitors**: Auto-discovery of application metrics
- **Node Exporter**: Host metrics
- **kube-state-metrics**: Kubernetes metrics

## Custom Dashboards

- Vote Application Overview
- Redis Performance
- PostgreSQL Performance
- Pod Resource Usage

## Access URLs

After port-forwarding:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- AlertManager: http://localhost:9093
