output "enabled_engines" {
  description = "Map of enabled engine paths to their types"
  value       = { for k, v in vault_mount.secret_engines : k => v.type }
}

output "policies_created" {
  description = "List of Vault policy names created from the policies/ folder"
  value       = keys(vault_policy.policies)
}
