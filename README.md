# Local Kubernetes Log Ingestion Pipeline

Automated log ingestion pipeline running entirely on a local kind cluster.

## Architecture
[log-producer] -> [Vector agent] -> [Kafka] -> [Vector consumer] -> [Elasticsearch] | [Kibana via Traefik]

## Prerequisites
- Docker Desktop (running, 8GB+ RAM recommended)
- [kind](https://kind.sigs.k8s.io/)
- kubectl
- helm

  # Deployment Guide

Follow the steps below to deploy the complete log ingestion pipeline on a local Kind Kubernetes cluster.

## Prerequisites

- Docker
- Kind
- kubectl
- Helm
- Python 3 (for the sample log producer)

---

## Deployment Steps

### 1. Create the project

Clone the repository and navigate into the project directory.

```bash
git clone <repository-url>
cd log-pipeline
```

---

### 2. Create the Kind Kubernetes cluster

Use the provided Kind configuration.

```bash
kind create cluster --name log-pipeline --config kind-config.yaml
```

---

### 3. Install Traefik Ingress Controller

Deploy Traefik using the supplied Helm values file.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

helm upgrade --install traefik traefik/traefik \
  -n traefik \
  --create-namespace \
  -f helm/traefik-values.yaml
```

Configuration file:

```
helm/traefik-values.yaml
```

---

### 4. Create the logging namespace

```bash
kubectl apply -f manifests/namespace.yaml
```

---

### 5. Install the Elastic Cloud on Kubernetes (ECK) Operator

Deploy the Elastic CRDs and Operator.

```bash
kubectl create -f https://download.elastic.co/downloads/eck/2.16.1/crds.yaml

kubectl apply -f https://download.elastic.co/downloads/eck/2.16.1/operator.yaml

kubectl wait \
  --for=condition=ready \
  pod \
  -l control-plane=elastic-operator \
  -n elastic-system \
  --timeout=120s
```

---

### 6. Deploy Elasticsearch

Deploy a single-node Elasticsearch cluster (Basic License).

```bash
kubectl apply -f manifests/eck/elasticsearch.yaml
```

---

### 7. Deploy Kibana

Deploy Kibana managed by the ECK Operator.

```bash
kubectl apply -f manifests/eck/kibana.yaml
```

---

### 8. Deploy Kafka

Install Kafka using the Bitnami Helm chart.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm upgrade --install kafka bitnami/kafka \
  -n logging \
  -f helm/kafka-values.yaml \
  --wait
```

Configuration file:

```
helm/kafka-values.yaml
```

---

### 9. Create the Kafka Topic

Create the topic used for log ingestion.

```bash
kubectl apply -f manifests/kafka-topic-job.yaml
```

Topic created:

```
app-logs
```

---

### 10. Build the Sample Log Producer

Application source:

```
apps/log-producer/main.py
```

Dockerfile:

```
apps/log-producer/Dockerfile
```

Build the Docker image.

```bash
docker build -t log-producer:local apps/log-producer
```

Load the image into the Kind cluster.

```bash
kind load docker-image log-producer:local --name log-pipeline
```

Deploy the application.

```bash
kubectl apply -f manifests/log-producer.yaml
```

---

### 11. Deploy the Vector Agent

The Vector Agent runs as a DaemonSet and collects Kubernetes container logs before forwarding them to Kafka.

Configuration:

```
manifests/vector-agent-config.yaml
```

Deployment:

```
manifests/vector-agent.yaml
```

The deployment includes:

- ServiceAccount
- ClusterRole
- ClusterRoleBinding
- DaemonSet

Apply:

```bash
kubectl apply -f manifests/vector-agent-config.yaml
kubectl apply -f manifests/vector-agent.yaml
```

---

### 12. Deploy the Vector Consumer

The Vector Consumer reads logs from Kafka and indexes them into Elasticsearch.

Configuration:

```
manifests/vector-consumer-config.yaml
```

Deployment:

```
manifests/vector-consumer.yaml
```

Apply:

```bash
kubectl apply -f manifests/vector-consumer-config.yaml
kubectl apply -f manifests/vector-consumer.yaml
```

---

### 13. Expose Kibana through Traefik

Deploy the Traefik IngressRoute.

```bash
kubectl apply -f manifests/traefik-kibana-ingressroute.yaml
```

---

### 14. Deploy Everything Automatically

A deployment script is included to automate the installation process.

```
deploy.sh
```

Run:

```bash
chmod +x deploy.sh

./deploy.sh
```

---

# Repository Structure

```
.
├── apps
│   └── log-producer
│       ├── Dockerfile
│       └── main.py
│
├── helm
│   ├── kafka-values.yaml
│   └── traefik-values.yaml
│
├── manifests
│   ├── namespace.yaml
│   ├── kafka-topic-job.yaml
│   ├── log-producer.yaml
│   ├── vector-agent.yaml
│   ├── vector-agent-config.yaml
│   ├── vector-consumer.yaml
│   ├── vector-consumer-config.yaml
│   ├── traefik-kibana-ingressroute.yaml
│   └── eck
│       ├── elasticsearch.yaml
│       └── kibana.yaml
│
├── kind-config.yaml
├── deploy.sh
└── README.md
```

---

# Architecture

```
Sample Log Producer
        │
        ▼
Vector Agent (DaemonSet)
        │
        ▼
      Kafka
        │
        ▼
Vector Consumer
        │
        ▼
 Elasticsearch
        │
        ▼
     Kibana
```
  
  
Note : the helm chart for the following were installed from the internet :

## One-command deploy
```bash
chmod +x deploy.sh scripts/verify.sh
./deploy.sh


# Add hosts entry:

sudo sh -c 'grep -q kibana.local /etc/hosts || echo "127.0.0.1 kibana.local" >> /etc/hosts' or port forward the kibana pod to port 5600  and test 

# Components

| Component | Technology |
|---|---|
| Kubernetes Cluster | kind |
| Ingress Controller | Traefik |
| Message Buffer | Apache Kafka (Bitnami, KRaft mode) |
| Log Storage | Elasticsearch 8.15 (ECK Operator, Basic/Free Tier) |
| Dashboard | Kibana |
| Log Shipper / Consumer | Vector (Agent + Kafka Consumer) |
| Credentials | Kubernetes Secrets (ECK-generated) |

---

# Scaling for Production

For high-throughput production environments, the following improvements should be considered:

## Kafka Scaling

- Scale Kafka from a single broker to a multi-broker cluster for higher availability and throughput.
- Enable topic partitioning using keys such as:
  - `service_name`
  - `trace_id`
  - `application_id`

This allows Kafka consumers to process messages in parallel while maintaining message ordering where required.

Configure Kafka retention policies to support replay during downstream failures:

```properties
retention.ms=<retention-period>
retention.bytes=<maximum-storage-size>

### Verification
./scripts/verify.sh


<img width="2574" height="516" alt="image" src="https://github.com/user-attachments/assets/a66cdbf1-b912-4c8e-b4bd-acf86b57e21e" />
<img width="2372" height="1486" alt="image" src="https://github.com/user-attachments/assets/ee8f8b20-99f4-4f98-9f03-cd11a9c3a5f3" />
<img width="1186" height="743" alt="Screenshot 2026-07-23 at 12 16 32 AM" src="https://github.com/user-attachments/assets/fd29069a-f22b-400a-88a1-419c41aafb5e" />




