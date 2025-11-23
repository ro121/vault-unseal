# Vault KMS Auto-Unseal on EKS (Terraform)

This project creates:

- An AWS KMS key and alias for Vault auto-unseal.
- An IAM role (IRSA) with `kms:Encrypt/Decrypt/DescribeKey` on that key.
- A Vault Deployment on EKS using the shared `eks_deployment` module.
- Vault configuration via `VAULT_LOCAL_CONFIG` with `seal "awskms"`.

## Prerequisites

- Existing EKS cluster (`cluster_name`).
- EKS cluster has IAM OIDC provider enabled.
- Access to the internal `eks_deployment` Terraform module.
- Route53 private zone (`domain_name`) already exists.

## Usage

```bash
terraform init
terraform apply
