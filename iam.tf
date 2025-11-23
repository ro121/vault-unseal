data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster" "eks_cluster_info" {
  name = var.cluster_name
}

locals {
  oidc_url_hostpath = replace(
    data.aws_eks_cluster.eks_cluster_info.identity[0].oidc[0].issuer,
    "https://",
    ""
  )

  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_url_hostpath}"

  role_name   = "vault-irsa-kms-${var.cluster_name}"
  policy_name = "vault-kms-policy"
}


module "vault_iam" {
  source       = "git::https://git.web.boeing.com/bds-data-platform/aws/reusable-code/terraform-modules/aws-iam-module.git?ref=oidc_support"
  aws_iam_scope = "eks"

  roles = [
    {
      name        = local.role_name
      description = "IAM Role for Vault EKS Service Account"

      assume_role_oidc = {
        provider_arn = local.oidc_provider_arn
        oidc_issuer  = data.aws_eks_cluster.eks_cluster_info.identity[0].oidc[0].issuer
        # IMPORTANT: use your real namespace + SA name here
        subject      = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
      }

      custom_policies = [local.policy_name]
    }
  ]

  policies = [
    {
      name = local.policy_name
      file = "config/vault-kms-policy.json"
      variables = {
        kms_key_arn = aws_kms_key.vault_unseal.arn
      }
    }
  ]
}
