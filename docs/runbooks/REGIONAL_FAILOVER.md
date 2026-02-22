# Regional Failover Runbook

## Trigger Conditions

1. Primary region sustained API 5xx and failed health checks.
2. Major control plane outage in primary region.
3. Declared regional incident by cloud provider.

## Execution Steps

1. Confirm primary API health alarm and CloudFront origin failures.
2. Verify CloudFront failover routing:
- web traffic to secondary web ALB origin
- API traffic to secondary API Gateway origin
3. Validate secondary EKS workloads are healthy and scaling.
4. Validate SQS ingestion queue and worker lambdas in secondary region are processing normally.
5. Promote Aurora secondary cluster (if write path required in DR mode).
6. Switch write traffic controls to DR region.
7. Validate synthetic probes and business transactions.
8. Declare DR active and begin incident communications.

## Recovery Steps

1. Restore primary region services.
2. Re-establish Aurora global topology.
3. Revert CloudFront origin preference to primary.
4. Run post-incident review and corrective actions.

## Evidence Capture

1. Alarm timeline.
2. RTO and RPO measured values.
3. User impact window.
4. Actions and approvals log.
