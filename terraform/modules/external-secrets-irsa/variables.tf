variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC issuer URL without https://"
  type        = string
}

variable "namespace" {
  type = string
}

variable "service_account_name" {
  type    = string
  default = "external-secrets-sa"
}

variable "secret_arn" {
  type = string
}
