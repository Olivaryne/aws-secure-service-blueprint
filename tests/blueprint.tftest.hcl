mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

run "secure_defaults" {
  command = plan

  variables {
    name            = "example-api"
    aws_region      = "us-east-1"
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/example-api@sha256:0123456789abcdef"
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.app) == 2 && length(aws_subnet.db) == 2
    error_message = "The default topology must span two AZs across public, app, and database tiers."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "The secure default must not create internet egress from private application subnets."
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 6 && length(aws_vpc_endpoint.s3) == 1
    error_message = "Private AWS service endpoints must be present by default."
  }

  assert {
    condition     = aws_db_instance.postgres.storage_encrypted && !aws_db_instance.postgres.publicly_accessible
    error_message = "PostgreSQL must remain encrypted and non-public."
  }

  assert {
    condition     = aws_db_instance.postgres.manage_master_user_password
    error_message = "RDS must own master-password generation and storage in Secrets Manager."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields && aws_lb.this.enable_deletion_protection
    error_message = "The ALB must reject invalid headers and retain deletion protection by default."
  }

  assert {
    condition     = aws_ecs_service.app.network_configuration[0].assign_public_ip == false
    error_message = "Fargate tasks must not receive public IP addresses."
  }

  assert {
    condition     = aws_ecs_service.app.deployment_circuit_breaker[0].enable && aws_ecs_service.app.deployment_circuit_breaker[0].rollback
    error_message = "ECS deployments must use an automatic rollback circuit breaker."
  }
}

run "per_az_nat_is_explicit" {
  command = plan

  variables {
    name             = "example-api"
    aws_region       = "us-east-1"
    certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    container_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/example-api@sha256:0123456789abcdef"
    nat_gateway_mode = "per_az"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "per_az mode must create one NAT gateway per application AZ."
  }
}

run "single_az_is_rejected" {
  command = plan

  variables {
    name            = "example-api"
    aws_region      = "us-east-1"
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/example-api@sha256:0123456789abcdef"
    az_count        = 1
  }

  expect_failures = [var.az_count]
}
