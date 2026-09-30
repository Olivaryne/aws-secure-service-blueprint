locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, index)
  }

  app_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, index + 4)
  }

  db_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, index + 8)
  }

  nat_azs = var.nat_gateway_mode == "none" ? [] : (
    var.nat_gateway_mode == "single" ? [local.azs[0]] : local.azs
  )

  interface_endpoint_services = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
    "kms",
    "sts",
  ])

  common_tags = merge(
    {
      Project   = var.name
      ManagedBy = "Terraform"
      Blueprint = "aws-secure-service-blueprint"
    },
    var.tags,
  )

  alarm_actions = var.alarm_sns_topic_arn == null ? [] : [var.alarm_sns_topic_arn]
}
