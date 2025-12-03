resource "kubernetes_job" "vault_log_extractor" {
  depends_on = [kubernetes_job.vault_init]

  metadata {
    name      = "vault-log-extractor"
    namespace = "vault"
  }

  spec {
    backoff_limit = 1

    template {
      spec {
        restart_policy = "Never"

        container {
          name  = "extractor"
          image = "bitnami/kubectl:latest"

          command = [
            "sh", "-c",
            <<-EOF
              # Wait for Vault init job to complete
              kubectl wait --for=condition=complete job/vault-init -n vault --timeout=120s

              # Extract LAST LOG LINE (this contains root_token + recovery keys)
              LAST_LINE=$(kubectl logs job/vault-init -n vault | tail -1)

              # Store inside Kubernetes Secret
              kubectl create secret generic vault-init-output \
                -n vault \
                --from-literal=output="$LAST_LINE" \
                --dry-run=client -o yaml | kubectl apply -f -
            EOF
          ]
        }
      }
    }
  }
}
