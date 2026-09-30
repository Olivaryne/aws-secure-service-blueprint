check "private_runtime_connectivity" {
  assert {
    condition     = var.create_vpc_endpoints || var.nat_gateway_mode != "none"
    error_message = "Private ECS tasks need either VPC endpoints or NAT egress to reach required AWS services."
  }
}

check "database_storage_bounds" {
  assert {
    condition     = var.db_max_allocated_storage >= var.db_allocated_storage
    error_message = "db_max_allocated_storage must be greater than or equal to db_allocated_storage."
  }
}

check "autoscaling_capacity_bounds" {
  assert {
    condition     = var.max_task_count >= var.desired_count
    error_message = "max_task_count must be greater than or equal to desired_count."
  }
}
