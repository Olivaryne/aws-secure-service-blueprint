# Operations

## Before deployment

Confirm the following before applying this blueprint to a real account:

1. The ACM certificate exists in the deployment region and covers the hostname you intend to publish.
2. The container image is available from a registry reachable by the selected egress model. With the default `nat_gateway_mode = "none"`, use private ECR or another path reachable without public internet access.
3. The application exposes the configured `health_check_path` and returns a 2xx/3xx response only when it is ready to receive traffic.
4. The application can read the RDS-managed secret from `DB_SECRET_ARN` and establish PostgreSQL TLS according to your client policy.
5. The selected AWS account already has organization-level controls appropriate for production use.
6. Remote Terraform state, locking, backup, and CI/CD identity have been designed outside this stack.

## Validate locally

```bash
make check
```

Equivalent commands:

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test -no-color
```

The test suite uses a mocked AWS provider, so validation does not require AWS credentials.

## Plan

Copy the example inputs and replace all placeholders:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=service.tfplan
```

Review the plan with particular attention to:

- account and region
- subnet CIDRs and selected Availability Zones
- NAT mode
- ACM certificate ARN
- immutable container image reference
- deletion-protection flags
- RDS class and storage
- SNS alarm destination

Do not commit `terraform.tfvars`, state files, or plans.

## Apply

```bash
terraform apply service.tfplan
```

After apply, validate:

- the ALB listener redirects HTTP to HTTPS
- the HTTPS listener serves the expected certificate
- all target-group members are healthy
- ECS tasks have no public IPs
- the service has at least two healthy tasks across the selected AZs
- the RDS instance is not publicly accessible
- VPC endpoint DNS resolves from the application subnets
- CloudWatch application and flow logs are receiving data
- the application can retrieve the database secret using its task role

## Application deployment model

This repository owns the infrastructure and task definition. In a real delivery pipeline, publish immutable images and update `container_image` to a digest or immutable tag.

The ECS deployment circuit breaker automatically rolls back a deployment that cannot reach steady state. This protects service availability but does not validate application semantics. Add deployment verification appropriate to the application, such as smoke tests, synthetic requests, or progressive traffic controls.

## Autoscaling

The ECS service starts at `desired_count` and target tracking can scale it up to `max_task_count` based on average CPU utilization.

Terraform intentionally ignores changes to the runtime desired count after creation. Without this rule, a later infrastructure apply could undo a scale-out event and create a control-loop conflict between Terraform and Application Auto Scaling.

## Alarm handling

The blueprint creates alarms for:

- target 5xx responses at the ALB
- sustained ECS CPU utilization
- sustained RDS CPU utilization
- low RDS free storage

Set `alarm_sns_topic_arn` to integrate these with an existing paging or notification path. Alert routing is deliberately not created here because escalation policy is an organizational concern.

## Database recovery

RDS keeps seven days of automated backups by default and creates a final snapshot when destruction is permitted unless `db_skip_final_snapshot = true`.

A production runbook should separately define:

- target RPO and RTO
- point-in-time restore procedure
- restore validation
- DNS/application cutover process
- credential rotation after incident recovery
- ownership for destructive database operations

Multi-AZ protects against infrastructure failure in an Availability Zone. It is not a substitute for backup and restore testing.

## Egress changes

Changing from `none` to `single` or `per_az` grants application subnets general internet egress through NAT.

Treat this as a security-sensitive change. Document why the workload needs public egress and consider whether an interface endpoint, PrivateLink service, proxy, or allowlisted egress design can satisfy the requirement more narrowly.

`single` NAT is cheaper but introduces an Availability Zone dependency for outbound traffic. `per_az` avoids that dependency at higher cost.

## Destruction

The default configuration intentionally resists casual destruction:

- ALB deletion protection is enabled.
- RDS deletion protection is enabled.
- RDS final snapshot is enabled.

A destroy therefore requires explicit configuration changes before Terraform can remove those resources. This is intentional friction for a production baseline.
