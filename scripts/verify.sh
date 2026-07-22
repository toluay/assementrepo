#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-logging}"

echo "==> Pods in $NAMESPACE"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "==> Kafka topics"
kubectl exec -n "$NAMESPACE" kafka-controller-0 -- kafka-topics.sh \
  --bootstrap-server localhost:9092 --list

echo ""
echo "==> Sample Kafka messages"
kubectl exec -n "$NAMESPACE" kafka-controller-0 -- kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic app-logs \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 10000 || true

echo ""
echo "==> Elasticsearch indices"
PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n "$NAMESPACE" \
  -o go-template='{{.data.elastic | base64decode}}')
kubectl run curl-es --rm -i --restart=Never -n "$NAMESPACE" \
  --image=curlimages/curl:8.11.1 -- \
  curl -s -u "elastic:${PASSWORD}" -k \
  "https://elasticsearch-es-http:9200/_cat/indices?v"

echo ""
echo "==> Kibana"
echo "URL:      http://kibana.local"
echo "User:     elastic"
echo "Password: ${PASSWORD}"
echo ""
echo "In Kibana: Stack Management -> Data Views -> Create app-logs-* (time field: @timestamp)"
echo "Then open Discover to view logs."
