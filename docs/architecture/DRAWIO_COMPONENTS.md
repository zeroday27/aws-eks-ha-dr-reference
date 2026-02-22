# draw.io Component Blueprint (Detailed)

## Global Layer

1. Users (Global)
2. Route 53
3. CloudFront Distribution
4. AWS WAF (CLOUDFRONT scope)
5. Web domain + API domain aliases on CloudFront

## Primary Region (`ap-southeast-1`)

1. VPC `10.0.0.0/16`
2. Public subnets:
- `10.0.1.0/24`
- `10.0.2.0/24`
- `10.0.3.0/24`
- NAT GW in each subnet
3. Private app subnets:
- `10.0.11.0/24`
- `10.0.12.0/24`
- `10.0.13.0/24`
- EKS cluster + frontend web ALB + internal NLB
4. Private data subnets:
- `10.0.21.0/24`
- `10.0.22.0/24`
- `10.0.23.0/24`
- Aurora + RDS Proxy + Redis
5. Private integration subnets:
- `10.0.31.0/24`
- `10.0.32.0/24`
- `10.0.33.0/24`
- API Gateway VPC link ENIs, Lambda ENIs, VPC endpoints
6. SQS event buffer + SQS DLQ + EventBridge bus + Lambda ingest/worker/consumers

## Secondary Region (`ap-southeast-2`)

1. VPC `10.1.0.0/16`
2. Public subnets:
- `10.1.1.0/24`
- `10.1.2.0/24`
- `10.1.3.0/24`
3. Private app subnets:
- `10.1.11.0/24`
- `10.1.12.0/24`
- `10.1.13.0/24`
4. Private data subnets:
- `10.1.21.0/24`
- `10.1.22.0/24`
- `10.1.23.0/24`
5. Private integration subnets:
- `10.1.31.0/24`
- `10.1.32.0/24`
- `10.1.33.0/24`
6. DR EKS, DR EventBridge, DR data services
7. DR SQS event buffer + DLQ + Lambda ingest/worker

## Cross Region Links

1. CloudFront web origin failover (Primary ALB -> Secondary ALB)
2. CloudFront API origin failover (Primary API Gateway -> Secondary API Gateway)
3. EventBridge global endpoint failover (Primary bus -> Secondary bus)
4. Aurora global replication (Primary -> Secondary)
