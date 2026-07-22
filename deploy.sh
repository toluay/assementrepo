#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-log-pipeline}"
NAMESPACE="${NAMESPACE:-logging}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Creating kind cluster (if missing)"
if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME" --config "$ROOT_DIR/kind/cluster.yaml"
fi

echo "==> Installing Traefik"
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f "$ROOT_DIR/helm/traefik-values.yaml" \
  --wait

echo "==> Creating namespace"
kubectl apply -f "$ROOT_DIR/kubernetes/namespace.yaml"

echo "==> Installing ECK operator (if missing)"
if ! kubectl get crd elasticsearches.elasticsearch.k8s.elastic.co >/dev/null 2>&1; then
  kubectl create -f https://download.elastic.co/downloads/eck/2.16.1/crds.yaml
  kubectl apply -f https://download.elastic.co/downloads/eck/2.16.1/operator.yaml
  kubectl wait --for=condition=ready pod -l control-plane=elastic-operator -n elastic-system --timeout=180s
fi

echo "==> Deploying Elasticsearch + Kibana"
kubectl apply -f "$ROOT_DIR/manifests/eck/elasticsearch.yaml"
kubectl apply -f "$ROOT_DIR/manifests/eck/kibana.yaml"
kubectl wait --for=condition=ready elasticsearch/elasticsearch -n "$NAMESPACE" --timeout=600s
kubectl wait --for=condition=ready kibana/kibana -n "$NAMESPACE" --timeout=600s

echo "==> Deploying Kafka"
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update
helm upgrade --install kafka bitnami/kafka \
  -n "$NAMESPACE" \
  -f "$ROOT_DIR/helm/kafka-values.yaml" \
  --timeout 10m \
  --wait

echo "==> Creating Kafka topic"
kubectl apply -f "$ROOT_DIR/manifests/kafka-topic-job.yaml"
kubectl wait --for=condition=complete job/create-app-logs-topic -n "$NAMESPACE" --timeout=120s

echo "==> Building and loading log-producer image"
docker build -t log-producer:v1 "$ROOT_DIR/apps/log-producer"
kind load docker-image log-producer:local --name "$CLUSTER_NAME"

echo "==> Deploying pipeline components"
kubectl apply -f "$ROOT_DIR/manifests/log-producer.yaml"
kubectl apply -f "$ROOT_DIR/manifests/vector-agent-rbac.yaml"
kubectl apply -f "$ROOT_DIR/manifests/vector-agent-config.yaml"
kubectl apply -f "$ROOT_DIR/manifests/vector-agent.yaml"
kubectl apply -f "$ROOT_DIR/manifests/vector-consumer-config.yaml"
kubectl apply -f "$ROOT_DIR/manifests/vector-consumer.yaml"
kubectl apply -f "$ROOT_DIR/manifests/ingress-kibana.yaml"

echo "==> Waiting for workloads"
kubectl rollout status deployment/log-producer -n "$NAMESPACE" --timeout=120s
kubectl rollout status deployment/vector-consumer -n "$NAMESPACE" --timeout=120s
kubectl rollout status daemonset/vector-agent -n "$NAMESPACE" --timeout=120s

echo ""
echo "Deployment complete."
echo "Add to /etc/hosts: 127.0.0.1 kibana.local"
echo "Run verification: ./scripts/verify.sh"
