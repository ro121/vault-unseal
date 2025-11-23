########################
# Locals mirrored from your current Vault deployment
########################

locals {
  cluster_name      = var.cluster_name

  oidc_url_hostpath = replace(
    data.aws_eks_cluster.this.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

########################
# 1) KMS key for Vault auto-unseal
########################

resource "aws_kms_key" "vault_unseal" {
  description             = "KMS key for Vault auto-unseal"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

########################
# 2) IAM policy + IRSA role for Vault
########################

resource "aws_iam_policy" "vault_kms" {
  name        = "vault-kms-${local.cluster_name}"
  description = "Allow Vault to use the KMS key for auto-unseal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = aws_kms_key.vault_unseal.arn
      }
    ]
  })
}

data "aws_iam_policy_document" "vault_irsa_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      # system:serviceaccount:<namespace>:<serviceaccount>
      variable = "${local.oidc_url_hostpath}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.vault_name}"]
    }
  }
}

resource "aws_iam_role" "vault_irsa" {
  name               = "vault-irsa-kms-${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.vault_irsa_trust.json
}

resource "aws_iam_role_policy_attachment" "vault_kms_attach" {
  role       = aws_iam_role.vault_irsa.name
  policy_arn = aws_iam_policy.vault_kms.arn
}

########################
# 3) Vault config (VAULT_LOCAL_CONFIG) with awskms seal
########################

locals {
  vault_local_config = jsonencode({
    listener = [
      {
        tcp = {
          address     = "0.0.0.0:8200"
          tls_disable = 1
        }
      }
    ]

    # storage – matches PVC mount_path (/vault/data)
    storage = {
      raft = {
        path    = "/vault/data"
        node_id = "vault-0"
      }
    }

    seal = {
      awskms = {
        region     = var.aws_region
        kms_key_id = aws_kms_key.vault_unseal.arn
      }
    }

    ui = true
  })

  vault_secret_data = {
    VAULT_LOCAL_CONFIG = local.vault_local_config
  }
}

########################
# 4) Call existing eks_deployment module to deploy Vault
########################

module "vault" {
  source = "git::https://git.web.boeing.com/bds-data-platform/aws/platform-services/terraform_modules/eks_deployment.git?ref=bdsdp-4236"

  # existing inputs you already use
  domain_name               = var.domain_name
  image                     = local.image
  cluster_name              = local.cluster_name
  image_pull_secret         = local.image_pull_secret
  name                      = local.name
  ports                     = local.ports
  namespace                 = local.namespace
  replicas                  = local.replicas
  type                      = local.type
  persistence               = local.persistence
  service_annotations       = local.service_annotations
  resources                 = local.resources
  pod_security_context      = local.pod_security_context
  container_security_context = local.container_security_context
  probes                    = local.probes

  # NEW: env + IRSA for KMS auto-unseal
  secret_data = local.vault_secret_data

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.vault_irsa.arn
  }
}
