variable "name" {
  description = "Short service name used as a resource prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 lowercase alphanumeric/hyphen characters and start with a letter."
  }
}

variable "aws_region" {
  description = "AWS region in which to deploy the blueprint."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. The subnet layout assumes enough space for twelve /20-style child networks from a /16 default."
  type        = string
  default     = "10.42.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones. Two is the minimum supported production topology."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "nat_gateway_mode" {
  description = "Outbound internet mode for the app tier: none, single, or per_az. AWS API access can remain private through VPC endpoints when set to none."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of: none, single, per_az."
  }
}

variable "create_vpc_endpoints" {
  description = "Create private endpoints for ECR, CloudWatch Logs, Secrets Manager, KMS, STS, and S3."
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public ALB on HTTP/HTTPS. HTTP is redirected to HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN used by the HTTPS listener."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/.+$", var.certificate_arn))
    error_message = "certificate_arn must be an ACM certificate ARN."
  }
}

variable "container_image" {
  description = "Immutable container image reference. Prefer a private ECR digest or immutable tag."
  type        = string
}

variable "app_port" {
  description = "Container and target-group port."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1024 && var.app_port <= 65535
    error_message = "app_port must be between 1024 and 65535."
  }
}

variable "health_check_path" {
  description = "HTTP path used by the ALB target group health check."
  type        = string
  default     = "/health"
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 2
    error_message = "desired_count must be at least 2 for the production baseline."
  }
}

variable "max_task_count" {
  description = "Maximum ECS task count used by target-tracking autoscaling."
  type        = number
  default     = 6

  validation {
    condition     = var.max_task_count >= 2
    error_message = "max_task_count must be at least 2."
  }
}

variable "target_cpu_utilization" {
  description = "Target average ECS CPU utilization percentage for service autoscaling."
  type        = number
  default     = 65

  validation {
    condition     = var.target_cpu_utilization >= 20 && var.target_cpu_utilization <= 90
    error_message = "target_cpu_utilization must be between 20 and 90."
  }
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "enable_execute_command" {
  description = "Enable ECS Exec. Keep disabled unless your operational model and IAM controls require it."
  type        = bool
  default     = false
}

variable "alb_deletion_protection" {
  description = "Protect the ALB against accidental deletion."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "PostgreSQL master username. The password is generated and managed by RDS in Secrets Manager."
  type        = string
  default     = "app_admin"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.small"
}

variable "db_allocated_storage" {
  description = "Initial RDS gp3 storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS storage autoscaling ceiling in GiB."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Deploy the RDS instance in Multi-AZ mode."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Protect the RDS instance against accidental deletion."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip a final RDS snapshot on destroy. Production environments should normally keep this false."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
  default     = 30
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN for CloudWatch alarm notifications."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Additional tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}
