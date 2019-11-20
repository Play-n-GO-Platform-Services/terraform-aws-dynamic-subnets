# Get object aws_vpc by vpc_id

locals {
  source_count = var.enabled ? 1 : 0
}


data "aws_vpc" "emr" {
  count = local.source_count
  id = var.vpc_id
}

data "aws_availability_zones" "available" {
  count = local.source_count
}
