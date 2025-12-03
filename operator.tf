resource "kubernetes_job" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = "security-services"
  }

  # Make sure Vault deployment + service exist first
  depends_on = [module.eks_deployment]

  spec {
    backoff_limit = 0

    template {
      metadata {
        name = "vault-init"
      }

      spec {
        restart_policy       = "Never"
        service_account_name = "vault" # or your SA

        container {
          name  = "vault-init"
          # Can be any tiny image with curl; here I assume your vault image already has curl.
          image = local.image

          command = ["/bin/sh", "-c"]

          # IMPORTANT: from inside cluster, prefer the Kubernetes Service DNS, not the ELB
          env {
            name  = "VAULT_ADDR"
            value = "http://vault.security-services.svc.cluster.local:8200"
          }

          args = [<<-EOT
            set -euo pipefail

            echo "Vault init job starting. VAULT_ADDR=${VAULT_ADDR}"

            echo "Waiting for Vault HTTP endpoint to be reachable..."
            # just wait until TCP/HTTP responds
            until curl -s "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; do
              echo "  still waiting for Vault at ${VAULT_ADDR} ..."
              sleep 5
            done

            echo "Checking if Vault is already initialized via /v1/sys/init..."
            INIT_JSON=$(curl -s "${VAULT_ADDR}/v1/sys/init")
            echo "Init status response: ${INIT_JSON}"

            if echo "${INIT_JSON}" | grep -q '"initialized":true'; then
              echo "Vault already initialized. Nothing to do."
              exit 0
            fi

            echo "Vault not initialized. Calling /v1/sys/init..."

            # POST to /v1/sys/init to perform the equivalent of 'vault operator init'
            # 5 recovery keys, threshold 3 – adjust if you need to
            INIT_RESULT=$(curl -s -X POST \
              -H "Content-Type: application/json" \
              --data '{"secret_shares":5,"secret_threshold":3}' \
              "${VAULT_ADDR}/v1/sys/init")

            echo "Vault initialization completed."
            echo "================= IMPORTANT ================="
            echo "Save the following JSON securely (contains"
            echo "Recovery Keys and Initial Root Token)."
            echo "---------------------------------------------"
            echo "${INIT_RESULT}"
            echo "============================================="

            exit 0
          EOT]
        }
      }
    }
  }
}
