terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "this" {
  name = var.domain_name
}

resource "cloudflare_record" "demo" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.subdomain
  value   = var.nlb_hostname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform for EKS Demo"
}
