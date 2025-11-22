terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}

resource "kubernetes_resource_quota" "dev_quota" {
  metadata {
    name      = "dev-quota"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "1"
      "requests.memory" = "1Gi"
      "limits.cpu"      = "2"
      "limits.memory"   = "2Gi"
    }
  }
}

resource "kubernetes_network_policy" "db_policy" {
  metadata {
    name      = "db-policy"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "db"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "worker"
          }
        }
      }
      from {
        pod_selector {
          match_labels = {
            app = "result"
          }
        }
      }
      ports {
        port     = "5432"
        protocol = "TCP"
      }
    }
  }
}
