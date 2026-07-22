# Local Kubernetes Log Ingestion Pipeline

Automated log ingestion pipeline running entirely on a local kind cluster.

## Architecture
[log-producer] -> [Vector agent] -> [Kafka] -> [Vector consumer] -> [Elasticsearch] | [Kibana via Traefik]

## Prerequisites
- Docker Desktop (running, 8GB+ RAM recommended)
- [kind](https://kind.sigs.k8s.io/)
- kubectl
- helm

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



