# Online Boutique Demo — Quick Start

This directory contains a pre-adapted version of [Google Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) mapped to the hotel HA/DR architecture.

## Service Mapping

| Hotel Service | Boutique Service | Tier | Port |
|---------------|------------------|------|------|
| `hotel-core` | checkoutservice | Critical | 5050 |
| `loyalty-account` | cartservice (Redis) | Critical | 7070 |
| `inventory-availability` | productcatalogservice | Critical | 3550 |
| `pricing-rules-engine` | currencyservice | Critical | 7000 |
| `reservation-orchestrator` | paymentservice | Critical | 50051 |
| `public-api-bff` | frontend (web UI) | Stateless | 8080 |
| `search-api` | recommendationservice | Stateless | 8080 |
| `hotel-content-api` | shippingservice | Stateless | 50051 |
| `session-api` | emailservice | Stateless | 8080 |
| `admin-ops-api` | adservice | Stateless | 9555 |
| `load-generator` | loadgenerator | Utility | — |

## Quick Deploy

```bash
# Deploy to current cluster
./scripts/deploy_demo.sh

# Access the web UI
kubectl get svc public-api-bff-external -n hotel

# Remove demo
./scripts/deploy_demo.sh --remove
```

## Architecture Highlights

- **Workload Isolation**: Critical services use `nodepool: critical` with tolerations; stateless services use `nodepool: stateless`
- **Security**: All pods run as non-root (UID 1000), read-only root filesystem, capabilities dropped
- **Redis**: In-cluster redis-cart for POC; production would use ElastiCache via the `data` Terraform stack
- **Images**: Public Google Artifact Registry (`v0.10.5`) — no ECR mirror needed for POC
- **Load Generator**: Simulates 10 concurrent users at 1 req/sec against the frontend

## For Production (ECR Mirror)

When you move to UAT/Prod, mirror images to your ECR:

```bash
AWS_ACCOUNT_ID="<your-account-id>"
AWS_REGION="ap-southeast-1"
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

SERVICES=(checkoutservice cartservice productcatalogservice currencyservice \
  paymentservice frontend recommendationservice shippingservice \
  emailservice adservice loadgenerator)

for svc in "${SERVICES[@]}"; do
  docker pull us-central1-docker.pkg.dev/google-samples/microservices-demo/${svc}:v0.10.5
  docker tag us-central1-docker.pkg.dev/google-samples/microservices-demo/${svc}:v0.10.5 \
    ${ECR_BASE}/hotel-${svc}:v0.10.5
  aws ecr create-repository --repository-name hotel-${svc} --region ${AWS_REGION} 2>/dev/null || true
  docker push ${ECR_BASE}/hotel-${svc}:v0.10.5
done
```
