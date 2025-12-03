resource "kubernetes_role" "vault_sa_job_access" {
  metadata {
    name      = "vault-sa-job-access"
    namespace = "security-services"
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "update"]
  }
}

resource "kubernetes_role_binding" "vault_sa_job_access_bind" {
  metadata {
    name      = "vault-sa-job-access-bind"
    namespace = "security-services"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_sa_job_access.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = "security-services"
  }
}

