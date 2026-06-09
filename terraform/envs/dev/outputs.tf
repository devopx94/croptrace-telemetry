output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "secrets_manager_secret_name" {
  value = module.secrets_manager.secret_name
}

output "external_secrets_irsa_role_arn" {
  value = module.external_secrets_irsa.role_arn
}
