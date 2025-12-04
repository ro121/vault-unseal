variable "vault_addr" {
  description = "Vault server URL (e.g. https://vault-dev.example.com:8200)"
  type        = string
}

variable "vault_token" {
  description = "Vault token with permission to manage mounts and policies"
  type        = string
  sensitive   = true
}

variable "secret_engines" {
  description = <<EOT
Map of secret engines to enable.
Key = mount path (e.g. 'secret', 'transit').
Example:
{
  secret = {
    type        = "kv-v2"
    description = "KV v2 backend for app secrets"
  }
}
EOT

  type = map(object({
    type        = string
    description = string
  }))
}
