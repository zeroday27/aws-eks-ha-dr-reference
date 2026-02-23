# Data Stack

Creates data services:
- Aurora PostgreSQL Global Database (primary writer + DR secondary cluster)
- Regional Redis clusters for cache locality
- AWS Secrets Manager credentials for DB (primary + secondary) and Redis
