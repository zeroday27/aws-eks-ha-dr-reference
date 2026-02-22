# Hotel Platform - Design Document (Revised 2026)

## 1. Executive Summary

This design implements an EKS-only container strategy with event-driven serverless integrations and multi-region active-passive resilience.

Core decisions:
1. All containerized services run on EKS with Karpenter.
2. API Gateway is the external API control plane for backend routes only.
3. EventBridge + Lambda handle asynchronous workflows.
4. CloudFront + WAF provide global security with split routing:
- web pages to EKS frontend ALB origins
- API paths to API Gateway origins
5. Aurora Global Database provides cross-region data resilience.

## 2. Architecture Decisions

### 2.1 EKS-Only Container Platform
- Removes ECS/Fargate split complexity.
- Keeps one operational model for platform team.
- Uses dedicated node pools (critical vs stateless) with taints and priority classes.

### 2.2 API Edge and Security
- Route53 -> CloudFront for both web and API domains.
- WAF at CloudFront blocks attacks before hitting regional origin.
- CloudFront default behavior routes web traffic (`/*`) to frontend ALB origins.
- CloudFront API behaviors route `/api/*` and `/v1/*` to API Gateway origins.
- API Gateway enforces throttling, auth controls, and backend API contract boundaries.
- API synchronous traffic reaches EKS through VPC Link and internal NLB.

### 2.3 Event-Driven Architecture (EDA)
- Async commands are accepted by API and queued to SQS through Lambda ingest.
- Lambda workers consume SQS and publish normalized domain events to EventBridge.
- Lambda consumers process integrations (notifications, CRM sync, audit, analytics).
- SQS + DLQ provide retry/replay durability and burst protection.
- EventBridge Global Endpoint provides regional failover.

### 2.4 Data Layer
- Aurora PostgreSQL Global Database (primary writer + DR secondary).
- RDS Proxy in both regions for connection management.
- Regional Redis clusters for low-latency cache reads.

## 3. Service Placement

### 3.1 Services on EKS
Critical domain services:
- hotel-core
- loyalty-account
- reservation-orchestrator
- inventory-availability
- pricing-rules-engine

Stateless APIs:
- public-api-bff
- search-api
- hotel-content-api
- session-api
- admin-ops-api

### 3.2 Services on Lambda/EventBridge
- notifications fanout
- CRM sync
- fraud async checks
- audit trail fanout
- analytics ingestion
- scheduled reconciliation

## 4. Public Interface Contracts

1. Mutation endpoints require `Idempotency-Key`.
2. API responses include `X-Correlation-Id`.
3. Regional diagnostics header `X-Served-Region` is returned.
4. Event payloads use versioned schemas (`eventVersion`).

## 5. Reliability and Scalability

1. 10x spike handling:
- HPA scales pods.
- Karpenter provisions compute capacity.
- Redis offloads reads.
- RDS Proxy protects DB connections.

2. Zero-downtime posture:
- Multi-AZ in each region.
- PDB + topology spread.
- CloudFront/API regional failover.
- Aurora cross-region replica promotion runbook.

## 6. Terraform Enterprise Standards

1. Stack split:
- `network`
- `platform-eks`
- `data`
- `edge`
- `observability`

2. Environment strategy:
- separate environments for `dev`, `uat`, `prod`
- separate state keys per environment and stack
- separate accounts are recommended for production isolation
- deployment promotion path: `dev -> uat -> prod`

3. Governance and security:
- Remote state in encrypted S3 with locking.
- Version-pinned modules/providers.
- CI gates: fmt, validate, tflint, tfsec, checkov, OPA.
- Drift detection and policy checks.

## 7. Testing and DR Drills

Required scenarios:
1. 10x traffic spike.
2. AZ outage.
3. bad deployment rollback.
4. EventBridge delivery failure -> DLQ replay.
5. Regional failover to secondary.
6. Security validation (WAF/IAM/secrets rotation).

## 8. Team Assignment (1 Senior, 2 Juniors)

1. Senior Engineer:
- platform architecture, security boundaries, DR/failover design.
2. Junior Engineer A:
- Terraform stacks, CI/CD governance pipeline, platform automation.
3. Junior Engineer B:
- observability, runbooks, game-day testing, incident workflows.
