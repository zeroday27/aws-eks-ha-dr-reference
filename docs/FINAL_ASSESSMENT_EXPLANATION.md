# Final Architecture Explanation for Assessment

## 1. Business Goal and Design Principles

The platform supports global hotel web/API traffic with zero-downtime posture and burst resilience for flash-sale traffic.

Design principles:
1. High availability first (multi-AZ + multi-region active/passive).
2. Decoupled asynchronous processing for spike absorption.
3. One container platform (EKS) for operational consistency.
4. Defense in depth from edge to workload and data tiers.

## 2. End-to-End Traffic Model

### 2.1 Edge and Routing

1. Route53 directs `www` and `api` domains to CloudFront.
2. CloudFront + AWS WAF enforce edge security and global delivery.
3. CloudFront path-based origin routing:
- `/*` -> frontend ALB (EKS web workloads)
- `/api/*` and `/v1/*` -> API Gateway

### 2.2 Synchronous API lane

1. API Gateway applies throttling and API boundary controls.
2. API Gateway VPC Link targets private NLB.
3. NLB routes to EKS backend services.

### 2.3 Asynchronous API lane (decoupled)

1. API command endpoint invokes Lambda ingest.
2. Lambda ingest validates contract and enqueues to SQS.
3. Worker Lambda consumes SQS and publishes normalized events to EventBridge.
4. EventBridge fans out to integration consumers (notifications, CRM, fraud, analytics, audit).
5. DLQ is used for replay and failure isolation.

This queue-first model protects downstream systems and smooths burst traffic.

## 3. Data Layer Architecture

1. Redis cache-aside for hot reads.
2. RDS Proxy for connection pooling and failover resilience.
3. Aurora global database for cross-region DR.

Read/write best-practice split:
- Write: App -> RDS Proxy writer -> Aurora primary writer.
- Read: App -> Redis (hit) else RDS Proxy reader -> Aurora replicas -> repopulate Redis.
- Immediate post-write reads can be routed to writer endpoint when strict read-after-write is needed.

## 4. High Availability and DR

1. Regional active/passive model:
- Primary `ap-southeast-1`
- Secondary `ap-southeast-2`
2. CloudFront origin failover for both web and API origins.
3. EventBridge global endpoint for event routing failover.
4. Aurora global replication with promotion runbook for DR.

## 5. Terraform Delivery Model

1. Stack split by blast radius and ownership:
- `network`
- `platform-eks`
- `data`
- `edge`
- `observability`
2. Environment isolation:
- `dev`, `uat`, `prod`
- independent state keys per environment and stack
- recommended separate AWS accounts per environment

## 6. Why this architecture

1. Balances operational simplicity (EKS-only container runtime) with decoupled event processing.
2. Handles traffic bursts via horizontal scaling + SQS buffering.
3. Maintains clear web/API traffic boundaries.
4. Supports enterprise controls for reliability, security, and progressive delivery.

## 7. POC Next Steps

1. Deploy dev environment stack sequence (network -> platform-eks -> data -> edge -> observability).
2. Deploy sample hotel app workloads to EKS.
3. Run test scenarios (10x spike, AZ outage, async queue drain, regional failover).
4. Capture metrics and DR evidence for final assessment submission.
