terraform {
  required_version = ">= 1.3.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

# -------------------------
# Provider configuration
# -------------------------
provider "vault" {
  address = var.vault_addr  # e.g. https://vault-dev.example.com:8200
  token   = var.vault_token # admin/bootstrap token
}

# -------------------------
# Enable secret engines
# -------------------------
# secret_engines is a map, where:
#   key   = mount path (e.g. "secret")
#   value = object with "type" and "description"
#
# Example in terraform.tfvars:
# secret_engines = {
#   secret = {
#     type        = "kv-v2"
#     description = "KV v2 backend for app secrets"
#   }
# }
#
resource "vault_mount" "secret_engines" {
  for_each = var.secret_engines

  path        = each.key                 # "secret"
  type        = each.value.type          # "kv-v2", "transit", "pki", etc.
  description = each.value.description

  # you can add options for kv-v2 if needed, e.g.:
  # options = each.value.type == "kv-v2" ? { version = "2" } : null
}

# -------------------------
# Load policy files
# -------------------------

# Discover all *.hcl files in ./policies
locals {
  policy_files = fileset("${path.module}/policies", "*.hcl")
}

# Create a vault_policy for each file
resource "vault_policy" "policies" {
  # for_each over the set of filenames
  for_each = toset(local.policy_files)

  # basic.hcl -> "basic", readonly.hcl -> "readonly", etc.
  name   = trimsuffix(each.value, ".hcl")
  policy = file("${path.module}/policies/${each.value}")

  # Make sure policies are applied after engines are mounted
  depends_on = [vault_mount.secret_engines]
}
