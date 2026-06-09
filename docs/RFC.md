# RFC: Project GreenField Hybrid Cloud Migration Strategy

## 1. Objective

VerdantRoute Logistics is migrating selected high-priority functions from an on-premises monolithic platform into AWS cloud-native microservices. The first implementation is the CropTrace Telemetry service, a two-tier Kubernetes application consisting of a stateless API and a stateful data buffer.

This RFC defines the target AWS landing zone, hybrid connectivity, compute model, security controls, secrets management model, delivery approach, observability model, and Phase 02 implementation using Terraform, Docker, Kubernetes, Kustomize, GitHub Actions, Docker Hub, Amazon EKS, and AWS Secrets Manager.

## 2. Scope

### In Scope

- AWS multi-account landing zone.
- Hybrid connectivity to the existing on-prem legacy database.
- External provider Site-to-Site VPN integration.
- EKS-based platform for CropTrace Telemetry API.
- Terraform-based VPC, EKS, IAM, and AWS Secrets Manager provisioning.
- Dockerized Python API.
- Kubernetes deployment using Kustomize overlays.
- Runtime secrets from AWS Secrets Manager using External Secrets Operator.
- CI/CD using GitHub Actions and Docker Hub.
- Baseline security, observability, scaling, and operational controls.

### Out of Scope

- Full monolith decomposition.
- Full production database migration.
- Complete disaster recovery implementation.
- Full enterprise IAM federation implementation.
- Full service mesh implementation.

## 3. AWS Landing Zone

The AWS environment will use AWS Organizations with separate accounts for isolation, governance, and blast-radius control.

Required account structure:

```text
Management Account
Security Account
Log Archive Account
Network Account
Shared Services Account
Dev Account
Stage Account
Prod Account
```

### Account Responsibilities

| Account | Responsibility |
|---|---|
| Management Account | AWS Organizations, SCPs, billing, account vending |
| Security Account | GuardDuty, Security Hub, Inspector, IAM Access Analyzer, security operations |
| Log Archive Account | Central CloudTrail, AWS Config, VPC Flow Logs, immutable audit logs |
| Network Account | Transit Gateway, Direct Connect, Site-to-Site VPN, Route 53 Resolver, Network Firewall |
| Shared Services Account | Shared CI/CD, artifact repositories, common platform tooling |
| Dev Account | Development EKS workloads and testing |
| Stage Account | Pre-production validation and release testing |
| Prod Account | Production workloads with strict access controls |

### Landing Zone Controls

- Use AWS IAM Identity Center for centralized workforce access.
- Use Service Control Policies to restrict unsafe actions.
- Enable CloudTrail, AWS Config, GuardDuty, Security Hub, and VPC Flow Logs centrally.
- Use AWS KMS encryption for logs, EBS, Secrets Manager, and managed databases.
- Separate production from lower environments using dedicated AWS accounts.

## 4. Identity and Access Strategy

Global engineering users will authenticate through IAM Identity Center with role-based permission sets.

Recommended roles:

```text
PlatformAdmin
DevOpsEngineer
Developer
SecurityEngineer
ReadOnlyAuditor
BreakGlassAdmin
```

Production access should require MFA, approval, and audit logging. CI/CD access to AWS must use GitHub OIDC role assumption instead of static AWS access keys.

## 5. Hybrid Connectivity and Networking

### Target Topology

```text
Industrial Plant / Factory
        |
Industrial Gateway / PLC
        |
On-Prem Legacy Database
        |
Direct Connect - primary
Site-to-Site VPN - backup
        |
AWS Transit Gateway
        |
Network Account
        |
Dev / Stage / Prod VPCs
```

### Network Decisions

- Use AWS Direct Connect as the preferred low-latency private connection.
- Use AWS Site-to-Site VPN as backup connectivity.
- Terminate external provider VPNs in the Network Account.
- Use AWS Transit Gateway for centralized routing.
- Use Route 53 Resolver inbound and outbound endpoints for hybrid DNS.
- Keep EKS workloads in private subnets.
- Use NAT Gateway for controlled outbound access.
- Use AWS Network Firewall or centralized inspection where required.

## 6. Compute and Orchestration

| Workload | Recommended AWS Service | Reason |
|---|---|---|
| Sorting Engine | Amazon EKS | High CPU, constant load, container scaling, node autoscaling |
| Export Compliance | AWS Lambda + S3 + EventBridge/SQS | Bursty, upload-driven event processing |
| Farmer Payouts | Step Functions + Lambda or ECS Fargate | Secure, auditable, low-frequency workflow |
| CropTrace Telemetry API | Amazon EKS | Required Kubernetes-based implementation |
| Demo Data Buffer | PostgreSQL StatefulSet | Meets assessment requirement for StatefulSet and PVC |
| Production Data Store | Amazon RDS/Aurora PostgreSQL | Managed HA, backup, patching, encryption |

## 7. Phase 02 Application Architecture

```text
Users / External Systems
        |
AWS Application Load Balancer
        |
Amazon EKS Ingress
        |
CropTrace API Deployment + HPA
        |
PostgreSQL Headless Service
        |
PostgreSQL StatefulSet
        |
1Gi Persistent Volume Claim
```

The API exposes:

```text
POST /api/v1/telemetry
GET  /api/v1/health
```

The health endpoint returns success only when PostgreSQL connectivity is healthy.

## 8. AWS Secrets Manager Approach

All runtime application secrets will be stored in AWS Secrets Manager, not directly in Kubernetes YAML files or GitHub.

### Secret Flow

```text
AWS Secrets Manager
        |
External Secrets Operator
        |
IRSA / EKS OIDC Role
        |
Kubernetes ExternalSecret
        |
Kubernetes Secret
        |
CropTrace API Pod envFrom secretRef
```

### Secret Names

```text
croptrace/dev/api
croptrace/stage/api
croptrace/prod/api
```

### Secret JSON Structure

```json
{
  "DB_USER": "croptrace",
  "DB_PASSWORD": "strong-password",
  "MONOLITH_API_KEY": "monolith-api-key"
}
```

### Kubernetes Secret Consumption

The application Deployment uses:

```text
envFrom:
  - configMapRef:
      name: croptrace-api-config
  - secretRef:
      name: croptrace-api-secret
```

The Kubernetes Secret is created by External Secrets Operator from AWS Secrets Manager.

### IAM Design

- Enable EKS OIDC provider.
- Create an IAM role for the External Secrets Operator service account.
- Allow only `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret`.
- Scope the IAM policy to the environment-specific secret ARN.
- Use separate roles and secrets for Dev, Stage, and Prod.

## 9. Kubernetes Design

### Kubernetes Resources

```text
Namespace
ConfigMap
ServiceAccount for External Secrets
SecretStore
ExternalSecret
Deployment
Service
Ingress
HorizontalPodAutoscaler
StatefulSet
Headless Service
PersistentVolumeClaim
NetworkPolicy
PodDisruptionBudget
```

### Kustomize Structure

```text
k8s/
├── base/
└── overlays/
    ├── dev/
    ├── stage/
    └── prod/
```

Base contains common manifests. Overlays patch environment-specific values such as namespace, hostnames, replica counts, database DNS names, image tags, AWS Secrets Manager secret names, and IRSA role annotations.

Deployment commands:

```bash
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/stage
kubectl apply -k k8s/overlays/prod
```

## 10. Containerization

The Dockerfile uses:

- Python slim base image.
- Non-root user.
- Minimal dependency installation.
- `.dockerignore` to reduce build context.
- Healthcheck.
- Environment-based configuration.
- Structured JSON logs to stdout/stderr.

## 11. CI/CD Strategy

GitHub Actions will:

1. Checkout source code.
2. Build Docker image.
3. Push image to Docker Hub.
4. Authenticate to AWS using GitHub OIDC.
5. Update kubeconfig for EKS.
6. Update Kustomize image tag.
7. Deploy using `kubectl apply -k`.
8. Wait for Kubernetes rollout status.

GitHub stores only CI/CD secrets such as Docker Hub token and AWS OIDC role ARN. Application runtime secrets are stored in AWS Secrets Manager.

## 12. Security Controls

### Application and Kubernetes

- Run application as non-root.
- Drop Linux capabilities.
- Use CPU and memory requests/limits.
- Use readiness and liveness probes.
- Use NetworkPolicy to allow only API pods to reach PostgreSQL.
- Use PodDisruptionBudget for API availability.
- Avoid hardcoded secrets.
- Use AWS Secrets Manager through External Secrets Operator.

### AWS

- Use private EKS worker nodes.
- Use least-privilege IAM.
- Use Security Groups and NACLs.
- Use KMS encryption.
- Use GuardDuty, Security Hub, CloudTrail, AWS Config, and VPC Flow Logs.
- Use account separation for Dev, Stage, and Prod.

## 13. Observability

Recommended stack:

```text
CloudWatch Container Insights
Prometheus
Grafana
Fluent Bit
OpenTelemetry
AWS X-Ray - optional
```

Monitor:

- API latency and error rate.
- Pod CPU and memory.
- HPA scaling events.
- PostgreSQL health.
- ALB 4xx/5xx errors.
- EKS node health.
- VPN tunnel status.
- Direct Connect status.
- Transit Gateway metrics.
- External Secrets sync status.

This allows the team to separate application failures, EKS issues, AWS network issues, and on-prem connectivity bottlenecks.

## 14. Resilience and Scaling

- CropTrace API uses Deployment with HPA.
- PostgreSQL uses StatefulSet and PVC for stable identity and storage.
- EKS managed node groups provide worker node scaling.
- PDB protects the API from voluntary disruption.
- Production should use RDS/Aurora instead of in-cluster PostgreSQL.
- Multi-AZ private subnets should be used for EKS nodes.

## 15. Deployment Commands

### Provision AWS Infrastructure

```bash
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --region ap-southeast-1 --name croptrace-dev-eks
```

### Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

### Deploy Application

```bash
kubectl apply -k k8s/overlays/dev
```

### Verify Secrets

```bash
kubectl get externalsecret -n croptrace-dev
kubectl get secret croptrace-api-secret-dev -n croptrace-dev
kubectl describe externalsecret croptrace-api-secret-dev -n croptrace-dev
```

### Verify Application

```bash
kubectl get pods -n croptrace-dev
kubectl get svc -n croptrace-dev
kubectl get ingress -n croptrace-dev
kubectl rollout status deployment/croptrace-api-dev -n croptrace-dev
```

### Test API

```bash
curl http://<ALB-DNS-NAME>/api/v1/health

curl -X POST http://<ALB-DNS-NAME>/api/v1/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "facility_id": "FAC-001",
    "timestamp": "2026-06-09T10:00:00Z",
    "crop_type": "Tea",
    "weight_kg": 1250.5,
    "quality_rating": 5
  }'
```

## 16. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| On-prem latency impacts API | Add timeout, retry, circuit breaker, async queue where needed |
| In-cluster DB is not production-grade | Use RDS/Aurora for production |
| Secret exposure | Use AWS Secrets Manager, External Secrets Operator, and IRSA |
| Cluster misconfiguration | Use Terraform, Kustomize, PR review, and policy-as-code |
| Large deployment change | Use small commits, pull requests, and progressive rollout |
| Network issue between AWS and on-prem | Monitor VPN, Direct Connect, Transit Gateway, DNS, and routes |

## 17. Decision Summary

- Use AWS Organizations with Management, Security, Log Archive, Network, Shared Services, Dev, Stage, and Prod accounts.
- Use Direct Connect and Site-to-Site VPN through Transit Gateway.
- Use EKS for CropTrace Telemetry API.
- Use Kustomize overlays for Dev, Stage, and Prod.
- Use Docker Hub as the assessment image registry.
- Use GitHub Actions for CI/CD.
- Use Terraform for VPC, EKS, IAM, and AWS Secrets Manager.
- Use External Secrets Operator and IRSA for Kubernetes secret injection.
- Use PostgreSQL StatefulSet for the assessment data tier.
- Recommend RDS/Aurora for production data tier.
