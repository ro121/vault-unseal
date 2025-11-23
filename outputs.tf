output "kms_key_id" {
  description = "KMS key ID used for Vault auto-unseal"
  value       = aws_kms_key.vault_unseal.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for Vault auto-unseal"
  value       = aws_kms_key.vault_unseal.arn
}

output "vault_irsa_role_arn" {
  description = "IAM role assumed by Vault pods via IRSA"
  value       = aws_iam_role.vault_irsa.arn
}
