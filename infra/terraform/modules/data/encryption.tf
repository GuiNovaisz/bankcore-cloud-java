data "aws_caller_identity" "current" {}
resource "aws_kms_key" "data" {
  description             = "BankCore RDS, Performance Insights and Redis encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  # KMS key-policy Resource=* means this key only; account root delegates IAM control.
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "AccountKeyAdministration", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }, Action = "kms:*", Resource = "*" }] })
}
resource "aws_kms_alias" "data" {
  name          = "alias/${var.name}-data"
  target_key_id = aws_kms_key.data.key_id
}
