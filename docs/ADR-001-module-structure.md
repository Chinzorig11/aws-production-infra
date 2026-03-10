# ADR-001: Modular Terraform Structure

## Status
Accepted

## Context
The initial infrastructure was defined in a single flat directory with all resources in individual .tf files. As the project grew to support multiple environments (dev, staging, prod), this approach created several problems:
- Code duplication across environments
- Inconsistent configurations between environments
- Difficulty testing individual components
- No clear ownership boundaries for different infrastructure layers

## Decision
Restructure the Terraform codebase into reusable modules, with each module encapsulating a logical infrastructure layer:

- **vpc** — Network infrastructure (VPC, subnets, NAT, routes)
- **compute** — EC2 instances with Auto Scaling
- **database** — RDS with Secrets Manager
- **loadbalancer** — ALB with optional WAF
- **monitoring** — CloudWatch alarms and dashboards

Each environment (dev/staging/prod) composes these modules with environment-specific parameters.

## Consequences

### Positive
- Modules are independently testable and validatable
- Environment configs are concise (only module calls + variables)
- Changes to one layer don't affect others
- New environments can be created in minutes
- Team members can work on different modules simultaneously

### Negative
- Initial setup requires more files and structure
- Module versioning needs careful management
- Cross-module dependencies require explicit output/input wiring
- Learning curve for team members unfamiliar with Terraform modules

## Alternatives Considered
1. **Terraform Workspaces only** — Rejected because workspaces share state and make environment isolation harder
2. **Terragrunt** — Considered but adds tooling complexity; native modules sufficient for current scale
3. **Separate repos per module** — Considered for future; monorepo is simpler for current team size
