# Hotel Platform Workload Placement

## Containerized Services (Run on EKS)

| Service | Tier | Why EKS |
|---|---|---|
| hotel-core | Critical domain | Transactional business logic, high control over scaling and scheduling |
| loyalty-account | Critical domain | Stateful domain behavior with strict SLO |
| reservation-orchestrator | Critical domain | Complex orchestration and controlled rollout requirements |
| inventory-availability | Critical domain | High-throughput read/write with fine-grained autoscaling |
| pricing-rules-engine | Critical domain | CPU-intensive rules and predictable runtime control |
| web-frontend | Stateless web | Frontend web pages served from EKS behind ALB for CloudFront origin |
| public-api-bff | Stateless API | Horizontally scalable API aggregation workload |
| search-api | Stateless API | Burst-friendly request profile |
| hotel-content-api | Stateless API | Read-heavy API workload |
| session-api | Stateless API | Low-latency stateless session handling |
| admin-ops-api | Stateless API | Internal API with controlled access |

## Edge and API Control Plane

| Component | Role |
|---|---|
| CloudFront + WAF | Global entry, DDoS/WAF controls, path-based origin routing, origin failover |
| Web ALB (EKS) | Frontend web origin for `/*` page and asset traffic |
| API Gateway | Backend API boundary for `/api/*` and `/v1/*` |
| VPC Link + Internal NLB | Private synchronous route from API Gateway to EKS |
| SQS (+ DLQ) | Asynchronous command buffering and backpressure control before worker processing |

## Serverless / Event-Driven Services (Run on Lambda)

| Event | Lambda Consumer |
|---|---|
| NotifyGuest | Notification fanout |
| CustomerProfileUpdated | CRM sync |
| FraudCheckRequested | Fraud/risk async processing |
| PointsDeducted | Audit trail fanout |
| SearchClicked | Analytics enrichment |
| ReconciliationSchedule | Scheduled reconciliation |

Serverless processing chain:
- API command ingestion Lambda -> SQS
- Worker Lambda -> EventBridge publication
