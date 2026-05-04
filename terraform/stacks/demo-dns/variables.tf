variable "cloudflare_api_token" {
  description = "Cloudflare API Token for managing DNS"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The main domain name managed in Cloudflare (e.g., yangonai.com)"
  type        = string
  default     = "yangonai.com"
}

variable "subdomain" {
  description = "The subdomain to use for the demo"
  type        = string
  default     = "demo"
}

variable "nlb_hostname" {
  description = "The public hostname of the AWS NLB or ALB"
  type        = string
}
