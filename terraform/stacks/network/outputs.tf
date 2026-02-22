output "primary" {
  value = {
    region                 = var.primary_region
    vpc_id                 = module.primary_vpc.vpc_id
    vpc_cidr               = module.primary_vpc.vpc_cidr
    public_subnet_ids      = module.primary_vpc.public_subnet_ids
    app_subnet_ids         = module.primary_vpc.app_subnet_ids
    data_subnet_ids        = module.primary_vpc.data_subnet_ids
    integration_subnet_ids = module.primary_vpc.integration_subnet_ids
    availability_zones     = module.primary_vpc.availability_zones
  }
}

output "secondary" {
  value = {
    region                 = var.secondary_region
    vpc_id                 = module.secondary_vpc.vpc_id
    vpc_cidr               = module.secondary_vpc.vpc_cidr
    public_subnet_ids      = module.secondary_vpc.public_subnet_ids
    app_subnet_ids         = module.secondary_vpc.app_subnet_ids
    data_subnet_ids        = module.secondary_vpc.data_subnet_ids
    integration_subnet_ids = module.secondary_vpc.integration_subnet_ids
    availability_zones     = module.secondary_vpc.availability_zones
  }
}
