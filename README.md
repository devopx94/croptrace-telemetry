# CropTrace Telemetry

This repository contains the Phase 02 implementation for the CropTrace Telemetry service.

## Components

- Python FastAPI application
- Production-ready Dockerfile
- Kubernetes manifests with Kustomize
- PostgreSQL StatefulSet with 1Gi volume
- ConfigMaps and Secrets
- HPA, NetworkPolicy, PDB
- Terraform for AWS VPC and EKS provisioning
- GitHub Actions CI/CD pipeline using Docker Hub

## Deployment Flow

1. Provision AWS infrastructure using Terraform.
2. Build and push Docker image to Docker Hub using GitHub Actions.
3. Deploy Kubernetes manifests using Kustomize overlay.
4. Access the application through AWS Load Balancer Controller ingress.

## Local Kubernetes Deployment

```bash
kubectl apply -k k8s/overlays/dev
```

## Check Deployment

```bash
kubectl get pods -n croptrace-dev
kubectl get svc -n croptrace-dev
kubectl get ingress -n croptrace-dev
```

## Test API

```bash
./scripts/test-api.sh http://<ALB-DNS-NAME>
```

## Terraform Deployment

```bash
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --region ap-southeast-1 --name croptrace-dev-eks
```

## GitHub Secrets Required

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
AWS_ROLE_TO_ASSUME
AWS_REGION
```


## AWS Secrets Manager Approach

This repository avoids static Kubernetes Secret values. Application secrets are stored in AWS Secrets Manager and synced into Kubernetes using External Secrets Operator.

Secret names:

```text
croptrace/dev/api
croptrace/stage/api
croptrace/prod/api
```

Install External Secrets Operator:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

Deploy with Kustomize:

```bash
kubectl apply -k k8s/overlays/dev
```


## GitHub Actions Pipeline

Pipeline file:

```text
.github/workflows/ci-cd-dockerhub-eks.yml
```

The pipeline builds the Docker image, pushes it to Docker Hub, connects to Amazon EKS using AWS OIDC, deploys the Kustomize overlay, verifies ExternalSecret sync, and waits for rollout status.
