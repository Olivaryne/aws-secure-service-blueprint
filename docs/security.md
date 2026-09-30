# Security model

This repository is a service-level reference architecture. Its goal is to make important security assumptions visible in code and to fail closed on a few high-value invariants.

## Threats considered

The baseline is designed to reduce exposure from:

- accidental direct exposure of application tasks or PostgreSQL
- plaintext database credentials in Terraform variables or task definitions
- unrestricted east-west access between tiers
- unreviewed single-AZ production deployment
- accidental deletion of stateful or public-edge resources
- failed ECS deployments that otherwise remain partially rolled out
- unnecessary general internet egress from private workloads
- configuration drift between application autoscaling and Terraform
- loss of basic network-forensics data

It is not a complete threat model for every application deployed on top of it.

## Network controls

### Public edge

Only the ALB is internet-facing. Public subnets are used for the ALB and optional NAT Gateways, not for application tasks or the database.

HTTP is accepted only to redirect to HTTPS. HTTPS terminates at the ALB with an operator-supplied ACM certificate and a TLS 1.2/1.3 policy.

### Application tier

Fargate tasks:

- run in private subnets
- receive no public IP addresses
- accept application traffic only from the ALB security group
- may reach PostgreSQL only on 5432
- may use HTTPS for private AWS endpoints or explicitly enabled NAT egress

### Data tier

PostgreSQL:

- is not publicly accessible
- sits in isolated subnets without a default internet route
- accepts 5432 only from the application security group

## Credential handling

The database master password is never an input variable.

RDS manages the password in Secrets Manager. The task definition receives only the secret ARN. The ECS task role can read that specific secret and use the data KMS key for decryption.

The execution role and application task role are intentionally separate:

- **execution role**: permissions needed by ECS to start the task, pull the image, and publish logs
- **task role**: permissions the running application itself may exercise

Applications should continue this model rather than placing broad AWS permissions on the execution role.

## Encryption

RDS storage is encrypted with a customer-managed KMS key. The same key protects the RDS-managed master credential. Automatic KMS key rotation is enabled.

TLS is required at the public edge. Application-to-database TLS remains an application and PostgreSQL client configuration concern and should be enabled by the consuming service.

## Egress policy

The default `nat_gateway_mode = "none"` deliberately avoids general outbound internet access from application subnets.

Private endpoints provide access to the AWS services needed for a typical ECR-hosted Fargate workload. If an application must call arbitrary public APIs, egress has to be turned on explicitly with either `single` or `per_az` NAT mode.

This is an intentional design choice: outbound connectivity is treated as a capability to grant, not an ambient default.

## Deployment safety

The ECS service uses a deployment circuit breaker with automatic rollback. Application Auto Scaling owns runtime desired-count changes, while Terraform ignores only that autoscaler-owned field.

ALB and RDS deletion protection are on by default. RDS also keeps a final snapshot by default when destruction is allowed.

## Audit and observability

The stack enables:

- VPC Flow Logs
- ECS Container Insights
- application logs in CloudWatch Logs
- PostgreSQL and RDS upgrade logs
- CloudWatch alarms for ALB target 5xx responses, ECS CPU, RDS CPU, and low RDS free storage

An SNS topic can be supplied for alarm actions. The blueprint does not create paging policy because notification ownership is organization-specific.

## Terraform-level security contracts

Native Terraform tests pin several important invariants:

- at least two Availability Zones
- separate public, application, and database subnet tiers
- no NAT Gateway in the default configuration
- private AWS service endpoints present by default
- encrypted, non-public PostgreSQL
- RDS-managed database credentials
- invalid-header dropping and deletion protection on the ALB
- no public IP on ECS tasks
- automatic ECS deployment rollback

The tests use a mocked AWS provider and do not require cloud credentials.

## Controls intentionally left outside this repository

These belong to a broader platform or organization layer and should be added where appropriate:

- AWS Organizations and SCPs
- centralized CloudTrail and immutable audit storage
- GuardDuty, Security Hub, Detective, and organization-wide Config rules
- AWS WAF and managed rule groups
- Shield Advanced
- Route 53 and DNSSEC
- container signing and admission policy
- vulnerability scanning and software-bill-of-material enforcement
- CI/CD workload identity and deployment roles
- remote Terraform state bootstrap and state-lock policy
- cross-account environment separation
- application authentication, authorization, rate limiting, and data classification

Keeping these boundaries explicit is preferable to implying that a reusable service stack can enforce organization-level governance by itself.
