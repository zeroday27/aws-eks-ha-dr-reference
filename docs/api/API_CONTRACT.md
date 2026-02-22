# Public API Contract (v1)

## Required Headers

1. `Idempotency-Key` (required for `POST`, `PUT`, `PATCH`, `DELETE`)
2. `X-Correlation-Id` (optional from client, generated if absent)

## Response Headers

1. `X-Correlation-Id`
2. `X-Served-Region`

## Standard Error Envelope

```json
{
  "error": {
    "code": "EVENT_PUBLISH_FAILED",
    "message": "Unable to enqueue command event",
    "retriable": true
  },
  "correlationId": "8f1d8da0-f0f3-4bb5-bf47-4435d2d732f6"
}
```

## Endpoint Categories

1. Frontend page routes: `/*` are served by web workloads on EKS behind CloudFront web ALB origin.
2. Synchronous domain APIs: `/api/*` and `/v1/*` via API Gateway VPC Link to EKS.
3. Asynchronous command ingestion: `POST /api/events/commands` (legacy: `POST /v1/events/commands`) via Lambda ingest -> SQS.
4. Asynchronous processing: SQS -> Lambda worker -> EventBridge.
