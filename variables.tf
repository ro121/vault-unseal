variable "aws_region" {
  description = "AWS region where the EKS cluster and KMS key exist"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
  default     = "eks-services"
}

variable "namespace" {
  description = "Kubernetes namespace where Vault will be deployed"
  type        = string
  default     = "security-services"
}

variable "vault_name" {
  description = "Kubernetes app/name for Vault"
  type        = string
  default     = "vault"
}

variable "domain_name" {
  description = "Route53 private zone used by the eks_deployment module (e.g. internal.example.com)"
  type        = string
}

variable "vault_image" {
  description = "Vault container image"
  type        = string
  # use whatever image you are already running
  default     = "registry.web.boeing.com/bds-data-platform/devops/registry/vault:0.0.8437236-dev"
}

variable "image_pull_secret" {
  description = "Kubernetes imagePullSecret name"
  type        = string
  default     = "gitlab"
}
