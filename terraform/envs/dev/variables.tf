variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "croptrace"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "secret_values" {
  description = "Initial secret values for AWS Secrets Manager. Use terraform.tfvars locally and never commit it."
  type = object({
    DB_USER          = string
    DB_PASSWORD      = string
    MONOLITH_API_KEY = string
  })
  sensitive = true
}
