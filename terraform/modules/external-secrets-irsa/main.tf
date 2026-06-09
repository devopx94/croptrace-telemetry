locals {
  role_name = "${var.project_name}-${var.environment}-external-secrets-irsa"
}

resource "aws_iam_role" "this" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "read_secrets" {
  name        = "${local.role_name}-read-secrets"
  description = "Allow External Secrets Operator to read CropTrace API secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = var.secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "read_secrets" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.read_secrets.arn
}
