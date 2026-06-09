variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "secret_values" {
  description = "Initial secret values. For real production, inject securely through CI/CD or create secrets manually."
  type = object({
    DB_USER          = string
    DB_PASSWORD      = string
    MONOLITH_API_KEY = string
  })
  sensitive = true
}
