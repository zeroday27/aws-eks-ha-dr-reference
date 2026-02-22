# Network Stack

Creates active/passive regional VPC foundations with:
- 3 AZ public subnets
- 3 AZ private app subnets (EKS workloads)
- 3 AZ private data subnets (Aurora/Redis)
- 3 AZ private integration subnets (Lambda ENI + VPC endpoints)
- NAT Gateway per AZ and interface VPC endpoints
