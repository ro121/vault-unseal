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
###############
# Build VAULT_LOCAL_CONFIG using KMS outputs
#######################

locals {
  vault_local_config = jsonencode({
    seal = {
      awskms = {
        region     = var.aws_region
        kms_key_id = data.aws_kms_alias.vault_unseal.target_key_arn
      }
    }
  })
  vault_secret_data = {
    VAULT_LOCAL_CONFIG = local.vault_local_config
  }
}

data "aws_iam_role" "vault_irsa" {
  name = "vault-irsa-kms-${var.cluster_name}"
}

data "aws_kms_alias" "vault_unseal" {
  name = "alias/vault-unseal"
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
  role_arn    = data.aws_iam_role.vault_irsa.arn   # from data lookup by name
  secret_data = local.vault_secret_data            # this injects VAULT_LOCAL_CONFIG
}
