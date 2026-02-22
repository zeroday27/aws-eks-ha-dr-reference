# Edge Stack

Creates edge and event-driven control plane:
- CloudFront + WAF global ingress with split routing:
- web routes (`/*`) -> frontend ALB origins (primary/secondary failover)
- API routes (`/api/*`, `/v1/*`) -> API Gateway origins (primary/secondary failover)
- Lambda event-ingest API (`POST /api/events/commands`) -> SQS buffer
- Lambda worker consumes SQS and publishes to EventBridge regional buses
- EventBridge global endpoint failover
- EventBridge consumer Lambda targets are optional and can be attached later
