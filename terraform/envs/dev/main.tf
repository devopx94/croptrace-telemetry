module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  cidr_block   = "10.10.0.0/16"
}

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_version    = "1.31"
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_id             = module.vpc.vpc_id
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name  = var.project_name
  environment   = var.environment
  secret_values = var.secret_values
}

module "external_secrets_irsa" {
  source = "../../modules/external-secrets-irsa"

  project_name         = var.project_name
  environment          = var.environment
  namespace            = "croptrace-${var.environment}"
  service_account_name = "external-secrets-sa-${var.environment}"
  secret_arn           = module.secrets_manager.secret_arn
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.cluster_oidc_issuer_url
}
