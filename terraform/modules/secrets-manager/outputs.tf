output "secret_arn" {
  value = aws_secretsmanager_secret.api.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.api.name
}
