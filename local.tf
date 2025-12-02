locals {

  # === NEW: VAULT_LOCAL_CONFIG with raft + KMS ===
  vault_local_config = jsonencode({
    disable_mlock = true

    listener = [{
      tcp = {
        address     = "0.0.0.0:8200"
        tls_disable = 1
      }
    }]

    ui = true

    storage = {
      raft = {
        path    = "/vault/data"
        node_id = "vault-0"
      }
    }

    seal = {
      awskms = {
        region     = var.region
        kms_key_id = data.terraform_remote_state.vault_kms.outputs.kms_key_arn
      }
    }
  })

  vault_secret_data = {
    VAULT_LOCAL_CONFIG = local.vault_local_config
  }
}
