# AWS Production Infrastructure — Terraform Modules

> **Senior-level** Infrastructure as Code project implementing production-grade AWS architecture with reusable Terraform modules, multi-environment deployment, remote state management, CI/CD pipeline, and automated policy enforcement.

[![Terraform CI/CD](https://github.com/Chinzorig11/aws-production-infra/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/Chinzorig11/aws-production-infra/actions)
[![tfsec](https://github.com/Chinzorig11/aws-production-infra/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Chinzorig11/aws-production-infra/actions)

## Architecture

```
                           ┌──────────────────────────────────────────┐
                           │            AWS Cloud (Multi-AZ)          │
  ┌─────────┐              │  ┌────────────────────────────────────┐  │
  │  Users   │──HTTPS──▶   │  │    WAF + CloudFront (CDN)         │  │
  └─────────┘              │  └──────────────┬─────────────────────┘  │
                           │                 │                        │
                           │  ┌──────────────▼─────────────────────┐  │
                           │  │      Application Load Balancer     │  │
                           │  │          (SSL Termination)         │  │
                           │  └──────┬───────────────┬─────────────┘  │
                           │         │               │                │
                           │  ┌──────▼──────┐ ┌──────▼──────┐       │
                           │  │ Public Sub 1│ │ Public Sub 2│       │
                           │  │ EC2 (ASG)   │ │ EC2 (ASG)   │       │
                           │  │ us-east-1a  │ │ us-east-1b  │       │
                           │  └──────┬──────┘ └──────┬──────┘       │
                           │         │               │                │
                           │  ┌──────▼──────┐ ┌──────▼──────┐       │
                           │  │Private Sub 1│ │Private Sub 2│       │
                           │  │ RDS Primary │ │ RDS Standby │       │
                           │  │   + Redis   │ │   + Redis   │       │
                           │  └─────────────┘ └─────────────┘       │
                           │                                          │
                           │  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
                           │  │   S3    │ │CloudWatch│ │ Secrets  │ │
                           │  │ (Logs)  │ │(Monitor) │ │ Manager  │ │
                           │  └─────────┘ └──────────┘ └──────────┘ │
                           └──────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │                    CI/CD Pipeline                                │
  │  PR Created → tflint → tfsec → terraform plan → Review          │
  │  Merged to main → terraform apply (dev) → promote → prod        │
  └─────────────────────────────────────────────────────────────────┘
```

## What Makes This Senior-Level?

| Feature | Junior Approach | This Project (Senior) |
|---------|----------------|----------------------|
| Code Organization | Single flat directory | **Reusable Terraform Modules** |
| Environments | One environment | **dev / staging / prod** with workspaces |
| State Management | Local `terraform.tfstate` | **Remote S3 + DynamoDB locking** |
| Secrets | Hardcoded or `.tfvars` | **AWS Secrets Manager + KMS** |
| Security | Basic Security Groups | **WAF + KMS + tfsec scanning** |
| Deployment | Manual `terraform apply` | **GitHub Actions CI/CD pipeline** |
| Policy | None | **OPA/Sentinel-style policy checks** |
| Testing | None | **Automated validation + plan tests** |
| Documentation | Basic README | **ADRs + module docs + runbooks** |

## Project Structure

```
.
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                    # Network infrastructure
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── compute/                # EC2 + Auto Scaling
│   ├── database/               # RDS + Secrets Manager
│   ├── loadbalancer/           # ALB + WAF
│   ├── monitoring/             # CloudWatch + SNS
│   └── security/               # KMS + IAM
├── environments/               # Per-environment configs
│   ├── dev/
│   │   ├── main.tf             # Dev environment root
│   │   ├── terraform.tfvars
│   │   └── backend.tf          # Remote state config
│   ├── staging/
│   └── prod/
├── policies/                   # Policy-as-code checks
│   └── enforce.rego            # OPA policy rules
├── tests/                      # Infrastructure tests
│   └── validate.sh
├── .github/workflows/          # CI/CD pipelines
│   ├── terraform-ci.yml        # PR validation
│   └── security-scan.yml       # Security scanning
├── docs/                       # Architecture decisions
│   └── ADR-001-module-structure.md
└── README.md
```

## Quick Start

```bash
# 1. Clone
git clone https://github.com/Chinzorig11/aws-production-infra.git
cd aws-production-infra

# 2. Initialize dev environment
cd environments/dev
terraform init

# 3. Plan
terraform plan

# 4. Apply (creates real resources — costs money)
terraform apply

# 5. Destroy when done
terraform destroy
```

## Module Usage

Each module is independently reusable:

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name         = "myapp"
  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
}

module "compute" {
  source = "../../modules/compute"

  project_name    = "myapp"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnet_ids
  instance_type   = "t3.micro"
  min_size        = 1
  max_size         = 3
}
```

## CI/CD Pipeline

Every Pull Request triggers:
1. **terraform fmt** — Code formatting check
2. **terraform validate** — Syntax validation
3. **tflint** — Linting for best practices
4. **tfsec** — Security vulnerability scanning
5. **terraform plan** — Preview infrastructure changes
6. **OPA policy check** — Custom policy enforcement

Merge to `main` triggers automatic deployment to dev.

## Environments

| Environment | Purpose | Auto-Deploy | Multi-AZ | WAF |
|------------|---------|-------------|----------|-----|
| dev | Development & testing | Yes (on merge) | No | No |
| staging | Pre-production validation | Manual | Yes | Yes |
| prod | Production workloads | Manual + approval | Yes | Yes |

## Author

**Chinzorig Ochirbat** — Production Support & Cloud Engineer
- GitHub: [Chinzorig11](https://github.com/Chinzorig11)
- LinkedIn: [chinzorig-o-53578021b](https://linkedin.com/in/chinzorig-o-53578021b)
