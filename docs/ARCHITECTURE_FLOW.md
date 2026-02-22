# Hotel Platform - Architecture Data Flow (EKS + EDA)

## 1) Global Request Flow

1. Global users resolve:
- `www.hotel.example.com` for frontend web pages
- `api.hotel.example.com` for backend APIs
2. Route 53 routes to CloudFront.
3. CloudFront applies AWS WAF (managed rules + rate limit).
4. CloudFront routes by path:
- `/*` (web) -> frontend ALB origin (primary region)
- `/api/*` and `/v1/*` (API) -> API Gateway origin (primary region)
5. On origin failure (5xx), CloudFront fails over to secondary region origins for both web and API.

## 2) API Routing Model

1. Synchronous requests (`/api/*`, `/v1/*`) are routed from API Gateway to EKS through VPC Link + internal NLB.
2. Asynchronous commands (`POST /api/events/commands`, legacy `/v1/events/commands`) invoke Lambda ingest.
3. Lambda ingest validates `Idempotency-Key`, enriches context, and enqueues to SQS.
4. Lambda worker consumes from SQS and publishes to EventBridge.

## 3) Event-Driven Flow

1. SQS buffers asynchronous command events to absorb bursts.
2. EventBridge custom bus receives normalized events from Lambda workers.
3. Rules route events to Lambda consumers:
- notifications
- CRM sync
- fraud checks
- audit fanout
- analytics enrichment
- scheduled reconciliation
4. Failed SQS processing is moved to DLQ for replay.
5. EventBridge Global Endpoint performs failover to secondary regional bus.

## 4) Regional Network Layout (Both Regions)

Per region: one VPC, 3 AZs, 4 subnet tiers.

- Public subnets:
  - NAT Gateway per AZ
  - public ingress components only when required
- Private app subnets:
  - EKS worker nodes and pods (core + stateless APIs)
  - internal NLB targets for API Gateway VPC link
- Private data subnets:
  - Aurora PostgreSQL cluster
  - RDS Proxy
  - Redis (ElastiCache)
- Private integration subnets:
  - Lambda ENIs for VPC-enabled functions
  - Interface VPC Endpoints: Secrets Manager, STS, ECR API, ECR DKR, CloudWatch Logs, KMS, SSM

## 5) Multi-Region Active-Passive Data Strategy

1. Aurora PostgreSQL Global Database:
- writer in primary
- cross-region secondary cluster for failover
2. RDS Proxy in each region to absorb connection spikes.
3. Redis in each region for low-latency cache.

## 5.1 Data Access Best Practice (Read/Write Split)

1. Write path:
- Application -> RDS Proxy (writer endpoint) -> Aurora primary writer
- On successful commit, invalidate/update Redis keys for affected entities.

2. Read path:
- Application -> Redis first (cache-aside)
- On cache miss, Application -> RDS Proxy (reader endpoint) -> Aurora read replicas
- Application repopulates Redis with short TTL.

3. Consistency control:
- For immediately-after-write reads (hotel confirmation), route to writer endpoint to avoid replica lag.

## 6) EKS Workload Placement

Critical domain services on EKS critical node pool:
- hotel-core
- loyalty-account
- reservation-orchestrator
- inventory-availability
- pricing-rules-engine

Stateless API services on EKS stateless node pool:
- web-frontend
- public-api-bff
- search-api
- hotel-content-api
- session-api
- admin-ops-api

Isolation controls:
- Karpenter NodePools
- taints/tolerations
- PriorityClasses (`critical-domain`, `stateless-api`)
- topology spread and pod anti-affinity

## 7) Diagram Components to Include

Global:
- Users, Route53, CloudFront, WAF, Shield, web+API domains

Primary Region (`ap-southeast-1`):
- VPC (public/app/data/integration subnets across 3 AZ)
- Frontend web ALB (CloudFront web origin)
- API Gateway, VPC Link, internal NLB, EKS
- EventBridge bus, Lambda ingest+worker, SQS buffer + DLQ
- Aurora writer + readers, RDS Proxy, Redis

Secondary Region (`ap-southeast-2`):
- Same components in warm-passive mode
- Aurora secondary cluster
- EventBridge secondary bus

Cross-region links:
- CloudFront web origin failover (primary ALB -> secondary ALB)
- CloudFront API origin failover (primary API Gateway -> secondary API Gateway)
- EventBridge global endpoint failover
- Aurora global replication
