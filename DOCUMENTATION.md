# Voting Application - Technical Documentation

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Implementation Details](#implementation-details)
4. [Setup & Deployment](#setup--deployment)
5. [Monitoring & Observability](#monitoring--observability)
6. [Security Implementation](#security-implementation)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Multi-Environment Support](#multi-environment-support)
9. [Troubleshooting](#troubleshooting)

---

## Project Overview

A distributed voting application demonstrating production-ready DevOps practices including containerization, Kubernetes orchestration, comprehensive monitoring, and automated CI/CD pipelines.

### Technology Stack

- **Containerization**: Docker, Docker Compose
- **Orchestration**: Kubernetes (k3s)
- **Infrastructure as Code**: Terraform, Helm
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus, Grafana, AlertManager
- **Security**: Trivy, NetworkPolicies, RBAC, Pod Security Admission

### Application Components

- **Vote Service** (Python/Flask): Frontend voting interface
- **Result Service** (Node.js/Express): Real-time results display via WebSockets
- **Worker Service** (.NET/C#): Background vote processor
- **Redis**: Message queue for votes
- **PostgreSQL**: Persistent vote storage

---

## Architecture

### Network Architecture

**Two-Tier Design:**

```
┌─────────────────────────────────────────────────┐
│              Frontend Tier                      │
│  ┌──────────────┐      ┌──────────────┐        │
│  │  Vote (8080) │      │Result (8081) │        │
│  └──────┬───────┘      └──────┬───────┘        │
│         │                     │                 │
└─────────┼─────────────────────┼─────────────────┘
          │                     │
┌─────────┼─────────────────────┼─────────────────┐
│         │   Backend Tier      │                 │
│  ┌──────▼──────┐       ┌──────▼──────┐         │
│  │    Redis    │       │  PostgreSQL │         │
│  └──────▲──────┘       └──────▲──────┘         │
│         │                     │                 │
│  ┌──────┴─────────────────────┘                │
│  │       Worker Service                        │
│  └─────────────────────────────────────────────┘
└─────────────────────────────────────────────────┘
```

### Data Flow

1. User submits vote → Vote service
2. Vote service → Redis (queue)
3. Worker service polls Redis → processes votes
4. Worker service → PostgreSQL (store)
5. Result service queries PostgreSQL → displays via WebSocket

---

## Implementation Details

### 1. Containerization

#### Docker Images

All services use multi-stage builds and non-root users:

**Vote Service** ([`vote/Dockerfile`](file:///home/abdullah/vote/vote/Dockerfile))
- Base: `python:3.11-slim`
- User: `appuser` (non-root)
- Optimizations: `pip --no-cache-dir`, package cleanup
- Health check: curl on port 80

**Result Service** ([`result/Dockerfile`](file:///home/abdullah/vote/result/Dockerfile))
- Base: `node:18-alpine`
- User: `node` (uid 1000)
- Optimizations: `npm ci --only=production`, cache cleanup
- Includes `wget` for health checks

**Worker Service** ([`worker/Dockerfile`](file:///home/abdullah/vote/worker/Dockerfile))
- Multi-stage build
- Build stage: `dotnet/sdk:7.0`
- Runtime stage: `dotnet/runtime:7.0`
- User: `appuser` (non-root)

#### Docker Compose Configuration

**File:** [`compose.yml`](file:///home/abdullah/vote/compose.yml)

**Features Implemented:**
- Two-tier networking (frontend/backend isolation)
- Resource limits on all containers:
  - Vote/Result/Worker: 0.25-0.5 CPU, 256MB-512MB RAM
  - Redis: 0.1-0.25 CPU, 128MB-256MB RAM
  - PostgreSQL: 0.25-0.5 CPU, 512MB-1GB RAM
- Restart policies: `unless-stopped`
- Health checks for all services
- Log rotation: 10MB max size, 3 files
- Environment variables for configuration
- Persistent volumes for PostgreSQL

---

### 2. Kubernetes Deployment

#### Helm Chart Structure

```
k8s/charts/vote-app/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values
├── values-dev.yaml               # Development environment
├── values-prod.yaml              # Production environment
└── templates/
    ├── vote-deployment.yaml      # Vote service deployment
    ├── result-deployment.yaml    # Result service deployment
    ├── worker-deployment.yaml    # Worker service deployment
    ├── services.yaml             # Service definitions
    ├── ingress.yaml              # Ingress rules
    ├── rbac.yaml                 # ServiceAccounts, Roles, RoleBindings
    ├── network-policies.yaml     # Zero-trust network policies
    └── pod-disruption-budgets.yaml # High availability
```

#### Security Contexts

**Pod-level security** (all deployments):
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```

**Container-level security:**
```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
```

#### Health Probes

**Liveness Probes:**
- Vote: HTTP GET / on port 80, initial delay 10s
- Result: HTTP GET / on port 80, initial delay 15s
- Worker: No liveness probe (stateless processor)

**Readiness Probes:**
- Vote: HTTP GET / on port 80, initial delay 5s, interval 5s
- Result: HTTP GET / on port 80, initial delay 5s, interval 5s

#### Resource Management

**Development Environment** (values-dev.yaml):
- 1 replica per service
- CPU: 50m request, 100m limit
- Memory: 64Mi request, 128Mi limit

**Production Environment** (values-prod.yaml):
- Vote: 3 replicas
- Result: 2 replicas
- Worker: 2 replicas
- CPU: 100m request, 200m limit
- Memory: 128Mi request, 256Mi limit

---

### 3. Network Policies (Zero-Trust)

**File:** [`k8s/charts/vote-app/templates/network-policies.yaml`](file:///home/abdullah/vote/k8s/charts/vote-app/templates/network-policies.yaml)

**Implementation:**

| Service | Ingress | Egress |
|---------|---------|--------|
| Vote | Ingress Controller only | Redis + DNS |
| Result | Ingress Controller only | PostgreSQL + DNS |
| Worker | None (no inbound) | Redis + PostgreSQL + DNS |
| Redis | Vote + Worker only | None |
| PostgreSQL | Result + Worker only | None |

**Key Features:**
- Pod selector matching by app label
- Explicit port definitions
- DNS resolution allowed for service discovery
- Default deny for unlisted traffic

---

### 4. RBAC (Role-Based Access Control)

**File:** [`k8s/charts/vote-app/templates/rbac.yaml`](file:///home/abdullah/vote/k8s/charts/vote-app/templates/rbac.yaml)

**Components:**

**ServiceAccounts:**
- `vote-sa`: For vote pods
- `result-sa`: For result pods
- `worker-sa`: For worker pods

**Roles (Least Privilege):**
- Read-only access to pods and services
- No write permissions
- No access to secrets or configmaps
- Namespace-scoped only

**RoleBindings:**
- Binds ServiceAccounts to respective Roles
- Per-service segregation

**Integration:**
All deployments reference their ServiceAccount:
```yaml
spec:
  serviceAccountName: vote-sa
```

---

### 5. High Availability

#### PodDisruptionBudgets

**File:** [`k8s/charts/vote-app/templates/pod-disruption-budgets.yaml`](file:///home/abdullah/vote/k8s/charts/vote-app/templates/pod-disruption-budgets.yaml)

**Configuration:**
- Vote: `minAvailable: 1`
- Result: `minAvailable: 1`
- Worker: `minAvailable: 1`

**Purpose:** Ensures at least 1 pod remains available during voluntary disruptions (node drains, updates)

---

### 6. Monitoring Stack

#### Prometheus + Grafana Deployment

**Files:**
- [`monitoring/values.yaml`](file:///home/abdullah/vote/monitoring/values.yaml) - Helm configuration
- [`monitoring/servicemonitors.yaml`](file:///home/abdullah/vote/monitoring/servicemonitors.yaml) - Service discovery
- [`monitoring/alerts.yaml`](file:///home/abdullah/vote/monitoring/alerts.yaml) - Alert rules
- [`monitoring/deploy.sh`](file:///home/abdullah/vote/monitoring/deploy.sh) - Automated deployment

#### Components Deployed

**kube-prometheus-stack** includes:
- Prometheus Operator
- Prometheus server
- Grafana
- AlertManager
- Node Exporter
- kube-state-metrics

**Configuration Highlights:**
- 7-day retention period
- 10Gi persistent storage
- NodePort services (30300, 30900, 30093)
- Pre-configured Grafana dashboards:
  - Kubernetes Cluster Monitoring (GnetId: 15661)
  - Redis Dashboard (GnetId: 11835)
  - PostgreSQL Dashboard (GnetId: 9628)

#### ServiceMonitors

Auto-discovery and scraping configuration for:
- Vote service (port: http, path: /metrics)
- Result service (port: http, path: /metrics)
- Worker service (port: metrics, path: /metrics)
- Redis (port: metrics)
- PostgreSQL (port: metrics)

Scrape interval: 30 seconds

#### Alert Rules

**Critical Alerts:**
- PodNotReady: Pod not ready for 5 minutes
- PostgreSQLDown: Database unavailable for 1 minute
- RedisDown: Cache unavailable for 1 minute
- VoteServiceDown: Vote service down for 2 minutes
- ResultServiceDown: Result service down for 2 minutes

**Warning Alerts:**
- HighPodRestartRate: Restart rate > 0.5 over 15 minutes
- HighMemoryUsage: Memory usage > 90% for 5 minutes
- HighCPUUsage: CPU usage > 80% for 10 minutes
- WorkerServiceDown: Worker down for 2 minutes

#### Access

**NodePort Access:**
- Grafana: http://localhost:30300 (admin/admin123)
- Prometheus: http://localhost:30900
- AlertManager: http://localhost:30093

**Port-Forward Access:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

---

### 7. CI/CD Pipeline

**File:** [`.github/workflows/ci-cd.yml`](file:///home/abdullah/vote/.github/workflows/ci-cd.yml)

#### Pipeline Stages

**1. Build and Scan (Matrix Build)**
- Runs on self-hosted runner (linux, x64)
- Builds 3 services in parallel: vote, result, worker
- Uses Docker Buildx
- Pushes to GitHub Container Registry (ghcr.io)
- Tags: `latest` and `<git-sha>`

**Features:**
- Docker layer caching (GitHub Actions cache)
- Multi-platform support ready
- Automated version tagging

**2. Security Scanning**
- Tool: Trivy (Aqua Security)
- Scans for: CRITICAL and HIGH vulnerabilities
- Output: SARIF format
- Integration: GitHub Security tab
- Runs per service (3 parallel scans)

**3. Deployment**
- Helm upgrade/install to k3s
- Namespace: Configurable (dev/prod)
- Uses environment-specific values files
- Sets image tags to git SHA
- Creates namespace if not exists

**4. Verification**
- Waits for rollout completion (5-minute timeout)
- Checks all 3 deployments: vote, result, worker
- Verifies pod status
- Lists endpoints

**5. Smoke Tests**
- Port-forwards to services
- HTTP health checks:
  - Vote service: GET http://localhost:8080/
  - Result service: GET http://localhost:8081/
- Exits on failure
- Cleans up port-forwards

#### Triggers

**Automatic:**
- Push to `main` branch

**Manual:**
- `workflow_dispatch` with environment selection
- Choose: dev or prod
- Default: dev

#### Environment Variables

- `REGISTRY`: ghcr.io
- `IMAGE_NAME`: ${{ github.repository }}
- `ENVIRONMENT`: ${{ github.event.inputs.environment || 'dev' }}

---

### 8. Infrastructure as Code

#### Terraform Configuration

**File:** [`terraform/main.tf`](file:///home/abdullah/vote/terraform/main.tf)

**Resources Managed:**

1. **Namespaces:**
   - `dev` namespace
   - `prod` namespace

2. **Resource Quotas:**
   - Dev namespace: 1 CPU / 1Gi memory requests, 2 CPU / 2Gi limits

3. **Network Policies:**
   - Database isolation policy
   - Allows only worker and result access to PostgreSQL

**Provider:** Kubernetes provider using local kubeconfig

---

### 9. Multi-Environment Support

#### Environment Configurations

**Development** ([`values-dev.yaml`](file:///home/abdullah/vote/k8s/charts/vote-app/values-dev.yaml)):
- Namespace: `dev`
- Lower resources for cost efficiency
- Single replica for testing
- Local image tags
- Ingress: vote.dev.local, result.dev.local

**Production** ([`values-prod.yaml`](file:///home/abdullah/vote/k8s/charts/vote-app/values-prod.yaml)):
- Namespace: `prod`
- Higher resources for performance
- Multiple replicas for HA (vote: 3, result: 2, worker: 2)
- Registry images (ghcr.io)
- Ingress: vote.prod.local, result.prod.local

#### Deployment Commands

```bash
# Deploy to dev
helm upgrade --install vote-app ./k8s/charts/vote-app \
  --namespace dev \
  --create-namespace \
  --values ./k8s/charts/vote-app/values-dev.yaml

# Deploy to prod
helm upgrade --install vote-app ./k8s/charts/vote-app \
  --namespace prod \
  --create-namespace \
  --values ./k8s/charts/vote-app/values-prod.yaml
```

---

## Setup & Deployment

### Prerequisites

- Docker and Docker Compose
- kubectl
- Helm 3.x
- k3s cluster
- GitHub account (for CI/CD)

### Local Development (Docker Compose)

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Check status
docker compose ps

# Stop services
docker compose down

# Rebuild specific service
docker compose build result --no-cache
docker compose up -d result
```

**Access:**
- Vote: http://localhost:8080
- Result: http://localhost:8081

### K3s Deployment

#### 1. Deploy Infrastructure (Postgres, Redis)

```bash
# Apply manifests
kubectl apply -f k8s/manifests/postgres.yaml
kubectl apply -f k8s/manifests/redis.yaml

# Verify
kubectl get pods -n dev
kubectl get pvc -n dev
```

#### 2. Deploy Monitoring

```bash
cd monitoring
./deploy.sh

# Verify
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

#### 3. Deploy Application

```bash
# Import images to k3s
./import-images.sh

# Deploy with Helm
helm upgrade --install vote-app ./k8s/charts/vote-app \
  --namespace dev \
  --create-namespace \
  --values ./k8s/charts/vote-app/values-dev.yaml

# Verify
kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev
```

#### 4. Access Application

**Via Port-Forward:**
```bash
kubectl port-forward -n dev svc/vote-app-vote 8080:80
kubectl port-forward -n dev svc/vote-app-result 8081:80
```

**Via Ingress (add to /etc/hosts):**
```
127.0.0.1 vote.dev.local result.dev.local
```

---

## Monitoring & Observability

### Grafana Dashboards

**Pre-configured Dashboards:**
1. Kubernetes Cluster Monitoring
2. Redis Performance Metrics
3. PostgreSQL Database Metrics

**Custom Metrics (if instrumented):**
- Vote count per option
- Votes per second
- Worker processing rate
- Queue depth

### Prometheus Queries

**Useful PromQL Queries:**

```promql
# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="dev"}[5m])

# Pod memory usage
container_memory_usage_bytes{namespace="dev"}

# Pod restart count
kube_pod_container_status_restarts_total{namespace="dev"}

# Service availability
up{namespace="dev"}
```

### Alert Management

**View Active Alerts:**
- AlertManager UI: http://localhost:30093

**Alert Routing:**
- Critical alerts → critical receiver
- Warning alerts → warning receiver
- Watchdog alerts → null receiver

**Alert Grouping:**
- By: alertname, cluster, service
- Group wait: 10s
- Group interval: 10s
- Repeat interval: 12h

---

## Security Implementation

### Defense in Depth

**Layer 1: Container Security**
- Non-root users in all images
- Read-only root filesystem where possible
- Minimal base images (alpine, slim)
- No unnecessary packages

**Layer 2: Pod Security Admission**
- RunAsNonRoot enforced
- Privilege escalation blocked
- All capabilities dropped
- Seccomp runtime default profile

**Layer 3: Network Security**
- NetworkPolicies enforce zero-trust
- Pod-to-pod traffic restricted
- Explicit allow lists
- DNS resolution allowed for service discovery

**Layer 4: RBAC**
- Least privilege ServiceAccounts
- Read-only permissions
- Namespace-scoped access
- No cluster-wide permissions

**Layer 5: Image Scanning**
- Trivy scans in CI/CD
- CRITICAL and HIGH severities fail build
- SARIF reports to GitHub Security
- Automated vulnerability detection

**Layer 6: Secrets Management**
- Kubernetes Secrets for sensitive data
- No secrets in values.yaml
- Secret references via secretKeyRef
- Base64 encoding (note: consider external secret management for production)

---

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
```

**Common causes:**
- Image pull failures → Check image exists in registry
- Resource limits → Check node capacity
- Failed health checks → Check application logs

#### 2. Service Not Accessible

**Check services:**
```bash
kubectl get svc -n dev
kubectl get endpoints -n dev
```

**Common causes:**
- No healthy pods → Check pod readiness
- Wrong port → Verify service definition
- NetworkPolicy blocking → Check network policies

#### 3. Database Connection Failures

**Check database pod:**
```bash
kubectl get pods -n dev -l app=postgres
kubectl logs <postgres-pod> -n dev
```

**Verify connectivity:**
```bash
kubectl exec -it <app-pod> -n dev -- nc -zv postgresql 5432
```

#### 4. Monitoring Not Showing Metrics

**Check ServiceMonitors:**
```bash
kubectl get servicemonitor -n dev
```

**Check Prometheus targets:**
- UI: http://localhost:30900/targets
- Look for state: UP/DOWN

**Common causes:**
- ServiceMonitor selector mismatch
- Metrics endpoint not exposed
- Firewall/NetworkPolicy blocking

### Logs and Debugging

**Application logs:**
```bash
# Docker Compose
docker compose logs -f vote

# Kubernetes
kubectl logs -f deployment/vote-app-vote -n dev
kubectl logs -f deployment/vote-app-result -n dev
kubectl logs -f deployment/vote-app-worker -n dev
```

**Events:**
```bash
kubectl get events -n dev --sort-by='.lastTimestamp'
```

**Resource usage:**
```bash
kubectl top pods -n dev
kubectl top nodes
```

---

## Project Structure

```
vote/
├── .github/
│   └── workflows/
│       └── ci-cd.yml              # GitHub Actions pipeline
├── healthchecks/
│   ├── postgres.sh                # PostgreSQL health check
│   └── redis.sh                   # Redis health check
├── k8s/
│   ├── charts/
│   │   └── vote-app/              # Helm chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       ├── values-dev.yaml    # Dev environment
│   │       ├── values-prod.yaml   # Prod environment
│   │       └── templates/         # K8s manifests
│   └── manifests/
│       ├── postgres.yaml          # PostgreSQL deployment
│       └── redis.yaml             # Redis deployment
├── monitoring/
│   ├── README.md                  # Monitoring setup guide
│   ├── values.yaml                # Prometheus stack config
│   ├── servicemonitors.yaml       # Service discovery
│   ├── alerts.yaml                # Alert rules
│   └── deploy.sh                  # Deployment script
├── result/
│   ├── Dockerfile                 # Result service image
│   ├── package.json               # Node dependencies
│   └── server.js                  # Express app
├── seed-data/
│   └── Dockerfile                 # Data seeding utility
├── terraform/
│   └── main.tf                    # Infrastructure as code
├── vote/
│   ├── Dockerfile                 # Vote service image
│   ├── requirements.txt           # Python dependencies
│   └── app.py                     # Flask app
├── worker/
│   ├── Dockerfile                 # Worker service image
│   ├── Program.cs                 # .NET worker
│   └── Worker.csproj              # Project file
├── compose.yml                    # Docker Compose config
├── import-images.sh               # K3s image import
└── README.md                      # Project overview
```

---

## References

### Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

### Helm Charts Used
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

### Best Practices
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [12-Factor App](https://12factor.net/)

---

## License

This project is created for DevOps assessment purposes.

## Author

Abdullah Hamada

---

**Last Updated:** November 22, 2025
