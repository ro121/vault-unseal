locals {
  # Service name is same as your app name in eks_deployment
  vault_service_name = local.name

  # Internal K8s DNS for Vault service
  vault_addr = "http://${local.vault_service_name}.${local.namespace}.svc.cluster.local:8200"
}


####################################

resource "kubernetes_job" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = local.namespace
    labels = {
      app = "vault-init"
    }
  }

  spec {
    backoff_limit = 1

    template {
      metadata {
        labels = {
          app = "vault-init"
        }
      }

      spec {
        # Use the same ServiceAccount as Vault (created by eks_deployment)
        service_account_name = local.name

        container {
          name  = "vault-init"
          # reuse the same image you pass into eks_deployment
          image = local.image

          env {
            name  = "VAULT_ADDR"
            value = local.vault_addr
          }

          command = ["/bin/sh", "-c"]
          args = [<<-EOC
            set -e

            echo "=== Vault status BEFORE init ==="
            vault status || true

            # Idempotent: if Vault is already initialized, do nothing
            if vault status 2>/dev/null | grep -q 'Initialized.*true'; then
              echo "Vault already initialized; nothing to do."
              exit 0
            fi

            echo "Vault is NOT initialized; running vault operator init..."
            vault operator init -format=json > /tmp/init.json

            echo "=== vault operator init output (JSON) ==="
            cat /tmp/init.json

            echo "=== Vault status AFTER init ==="
            vault status || true

            echo "vault-init job completed successfully."
          EOC
          ]
        }

        restart_policy = "OnFailure"
      }
    }
  }
}



data "http" "vault_health" {
  # if you’re fronting Vault with TLS, switch to https
  url = "http://vault.${var.domain_name}/v1/sys/health"
}

output "vault_health" {
  description = "Raw sys/health JSON from Vault (initialized/sealed/etc.)"
  value       = data.http.vault_health.body
}
