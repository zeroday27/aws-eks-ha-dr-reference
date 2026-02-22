# Reliability and Security Test Plan

## 1. Spike Test (10x)

- Generate baseline and burst traffic against `/v1/*`.
- Validate HPA and Karpenter scale-up behavior.
- Verify p95 latency and error rate SLO during burst.

## 2. AZ Failure Test

- Drain/disable one AZ node capacity.
- Validate continued service availability and pod redistribution.

## 3. Bad Deployment Test

- Push an intentionally failing deployment.
- Validate progressive rollout halt and rollback.

## 4. Event Failure Test

- Force Lambda consumer failures.
- Validate SQS backlog growth and controlled worker drain behavior.
- Validate EventBridge retry behavior and SQS DLQ capture.
- Replay DLQ events and confirm successful processing.

## 5. Regional Failover Drill

- Simulate primary web origin outage and verify CloudFront failover to secondary web ALB.
- Simulate primary API origin outage and verify CloudFront failover to secondary API Gateway.
- If required, promote Aurora secondary for write traffic.

## 6. Security Validation

- Validate WAF rule efficacy with controlled attack simulation.
- Validate IAM least-privilege and denied actions.
- Validate secret rotation and application continuity.

## 7. Terraform Governance Validation

- Execute CI checks: fmt, validate, tflint, tfsec, checkov, OPA.
- Run scheduled drift detection and confirm alerting.
