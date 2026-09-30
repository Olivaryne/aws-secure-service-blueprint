# AWS Secure Service Blueprint

A production-oriented Terraform reference architecture for running an internet-facing service on AWS with explicit **security, reliability, and operational boundaries**.

This repository is intentionally not a "hello world" Terraform example. It demonstrates how I approach a small production service when the important requirements are private compute, isolated data, least-privilege runtime identity, deliberate egress, encrypted credentials, failure-aware deployments, observable infrastructure, and testable security invariants.

## Architecture

```text
Internet
   |
   | HTTPS 443
   v
+-------------------------+
| Application Load        |   Public subnets, multi-AZ
| Balancer                |
+-------------------------+
             |
             | application port only
             v
+-------------------------+
| ECS / Fargate           |   Private app subnets, no public IPs
| minimum 2 tasks         |
+-------------------------+
       |           |
       | 5432      | HTTPS
       v           v
+-------------+  +-----------------------------+
| RDS         |  | Private AWS endpoints       |
| PostgreSQL  |  | ECR, Logs, Secrets, KMS,    |
| isolated    |  | STS and S3                  |
+-------------+  +-----------------------------+
```

See [docs/architecture.md](docs/architecture.md) for the full trust-boundary and routing model.

## What this blueprint demonstrates

### Network isolation

- multi-AZ VPC with separate public, application, and database subnet tiers
- only the ALB is internet-facing
- ECS tasks receive no public IP addresses
- PostgreSQL has no public route and is not publicly accessible
- security-group references enforce ALB → app → database traffic boundaries
- VPC Flow Logs provide network-forensics data

### Deliberate outbound access

The default is `nat_gateway_mode = "none"`.

Private VPC endpoints provide access to ECR, CloudWatch Logs, Secrets Manager, KMS, STS, and S3 without granting the application general internet egress.

If the workload genuinely needs arbitrary outbound internet access, NAT must be enabled explicitly as either:

- `single` — lower cost, but an AZ dependency for outbound traffic
- `per_az` — resilient per-AZ egress at higher cost

Terraform rejects a configuration that provides neither private AWS endpoints nor NAT egress.

### Credential and IAM boundaries

- RDS generates and manages the database master password in Secrets Manager
- database passwords are never Terraform inputs
- the task definition receives a secret **ARN**, not secret material
- ECS execution and application task identities are separate
- the application role can read only the database credential it needs and use the corresponding KMS key

### Encryption and data protection

- RDS storage encrypted with a customer-managed KMS key
- KMS automatic key rotation enabled
- RDS Multi-AZ enabled by default
- seven-day automated backups
- storage autoscaling
- deletion protection enabled by default
- final snapshot retained by default when destruction is allowed

### Failure-aware application delivery

- minimum two Fargate tasks
- ALB health checking
- ECS deployment circuit breaker
- automatic failed-deployment rollback
- target-tracking CPU autoscaling
- Terraform yields ownership of runtime desired count to Application Auto Scaling

### Observability

- ECS Container Insights
- application logs in CloudWatch Logs
- VPC Flow Logs
- PostgreSQL and upgrade log export
- RDS Performance Insights
- alarms for target 5xx responses, ECS CPU, RDS CPU, and low database free storage
- optional integration with an existing SNS notification path

## Security invariants are executable

The repository uses Terraform-native tests with a mocked AWS provider. The tests do not need AWS credentials and verify that important defaults stay true, including:

- two-AZ minimum topology
- three distinct network tiers
- no NAT Gateway by default
- private AWS endpoints present by default
- encrypted and non-public PostgreSQL
- RDS-managed credentials
- protected ALB defaults
- no public IPs on ECS tasks
- automatic ECS deployment rollback

This is deliberate: important infrastructure assumptions should be testable contracts, not comments in a diagram.

## Repository structure

```text
.
├── checks.tf                 # Cross-variable fail-closed assertions
├── compute.tf                # ALB, ECS, task/execution IAM
├── database.tf               # KMS and PostgreSQL
├── endpoints.tf              # Private AWS service access
├── network.tf                # VPC, subnets, routing, optional NAT
├── observability.tf          # Flow logs and CloudWatch alarms
├── scaling.tf                # ECS target-tracking autoscaling
├── security.tf               # Tier security-group boundaries
├── variables.tf              # Inputs and validation
├── outputs.tf
├── tests/
│   └── blueprint.tftest.hcl  # Terraform-native infrastructure tests
├── docs/
│   ├── architecture.md
│   ├── security.md
│   └── operations.md
└── .github/workflows/ci.yml  # fmt, validate and terraform test
```

## Quick validation

Terraform `>= 1.8` is required.

```bash
make check
```

Or run the steps directly:

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test -no-color
```

## Example deployment inputs

Start from the provided example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

At minimum, supply:

```hcl
name            = "example-api"
aws_region      = "us-east-1"
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/example-api@sha256:..."
```

Then:

```bash
terraform init
terraform plan
```

For a real environment, remote state, state locking, CI deployment identity, DNS, and account-level governance should be designed outside this service stack.

## Design decisions and tradeoffs

A useful infrastructure reference should say what it **does not** solve.

This repository intentionally leaves organization-level controls outside the service module, including AWS Organizations/SCPs, centralized CloudTrail, GuardDuty, Security Hub, WAF policy, Route 53/DNSSEC, container signing, remote-state bootstrap, and cross-account environment separation.

Those are platform concerns. Pretending a service stack owns them would make the reference architecture look more complete while actually making its authority boundaries less clear.

See:

- [Architecture](docs/architecture.md)
- [Security model](docs/security.md)
- [Operations and recovery](docs/operations.md)

## Purpose

This repository is a sanitized public engineering reference. It contains no employer code and no proprietary Teralli implementation. Its purpose is to show a concrete infrastructure pattern with architecture, implementation, tests, CI, security reasoning, and operational tradeoffs in one reviewable repository.
