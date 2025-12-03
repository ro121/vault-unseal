resource "kubernetes_job" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = "security-services"
  }

  spec {
    backoff_limit = 0

    template {
      metadata {
        name = "vault-init"
      }

      spec {
        restart_policy       = "Never"
        service_account_name = "vault" # <- or whatever SA your vault pods use

        container {
          name  = "vault-init"
          image = local.image  # or "hashicorp/vault:1.20.3" if you prefer
          command = ["/bin/sh", "-c"]

          env {
            name  = "VAULT_ADDR"
            value = "http://vault.${var.domain_name}"  # e.g. http://vault.squad-exploration.aws.boeing.com
          }

          args = [<<-EOT
            set -euo pipefail

            echo "Vault init job starting. VAULT_ADDR=${VAULT_ADDR}"

            echo "Waiting for Vault HTTP endpoint to be reachable..."
            # Only check connectivity, not status codes
            until curl -s "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; do
              echo "  still waiting for Vault at ${VAULT_ADDR} ..."
              sleep 5
            done

            echo "Checking if Vault is already initialized..."
            if vault status 2>&1 | grep -q 'Initialized.*true'; then
              echo "Vault already initialized. Nothing to do."
              exit 0
            fi

            echo "Vault not initialized. Running 'vault operator init'..."
            # defaults: 5 recovery keys, threshold 3 – good for most cases
            vault operator init > /tmp/vault-init.txt

            echo "Vault initialization completed."
            echo "================= IMPORTANT ================="
            echo "Copy the following Recovery Keys + Root Token"
            echo "and store them securely (e.g. password vault)."
            echo "---------------------------------------------"
            cat /tmp/vault-init.txt
            echo "============================================="

            exit 0
          EOT]
        }
      }
    }
  }
}
