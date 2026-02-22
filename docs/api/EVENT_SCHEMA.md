# Event Schema Contract

All events published to EventBridge must include:

```json
{
  "eventVersion": "1.0",
  "correlationId": "uuid",
  "idempotencyKey": "string",
  "payload": {}
}
```

## Required EventBridge Envelope

1. `source`: `hotel.api`
2. `detail-type`: domain-specific event type (`NotifyGuest`, `PointsDeducted`, etc.)
3. `detail`: JSON payload containing the contract above.

## Compatibility Rules

1. `eventVersion` is mandatory.
2. New fields must be additive for minor versions.
3. Breaking payload changes require a new major version and dedicated consumer rollout.
