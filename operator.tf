locals {
  # Service name and namespace are already defined in your locals
  vault_addr         = "http://vault.${var.domain_name}"
}

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
        # Use the same ServiceAccount as Vault
        service_account_name = local.name
        restart_policy       = "OnFailure"

        container {
          name  = "vault-init"
          image = local.image   # same image you use in eks_deployment

          env {
            name  = "VAULT_ADDR"
            value = local.vault_addr
          }

          command = ["/bin/sh", "-c"]
          args = [<<-EOC
            set -e

            echo "Waiting for Vault endpoint at ${VAULT_ADDR} to be reachable..."

            # Wait up to ~5 minutes for Vault to start listening
            for i in $(seq 1 30); do
              if vault status >/dev/null 2>&1; then
                echo "Vault endpoint is responding."
                break
              fi
              echo "Vault not ready yet (attempt $i/30), sleeping 10s..."
              sleep 10
            done

            echo "=== Vault status BEFORE init (may show uninitialized/sealed) ==="
            vault status || true

            # If already initialized, nothing to do (idempotent)
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
      }
    }
  }

  # Ensure Vault Deployment/Service/SA exist before this job runs
  depends_on = [module.eks_deployment]
}

data "http" "vault_health" {
  # if you’re fronting Vault with TLS, switch to https
  url = "http://vault.${var.domain_name}/v1/sys/health"
}