locals {
  secret_name = "${var.project_name}/${var.environment}/api"
}

resource "aws_secretsmanager_secret" "api" {
  name                    = local.secret_name
  description             = "CropTrace API secrets for ${var.environment}"
  recovery_window_in_days = 7

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "api" {
  secret_id = aws_secretsmanager_secret.api.id

  secret_string = jsonencode({
    DB_USER          = var.secret_values.DB_USER
    DB_PASSWORD      = var.secret_values.DB_PASSWORD
    MONOLITH_API_KEY = var.secret_values.MONOLITH_API_KEY
  })
}
