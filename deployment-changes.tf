variable "secret_data" {
  description = "Environment variables to inject via Kubernetes Secret (key=value)"
  type        = map(string)
  default     = {}
}

variable "service_account_annotations" {
  description = "Annotations to add to the ServiceAccount (e.g. IRSA role ARN)"
  type        = map(string)
  default     = {}
}

resource "kubernetes_service_account" "app" {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = var.service_account_annotations
  }
}


resource "kubernetes_secret" "app_secret" {
  count = length(var.secret_data) > 0 ? 1 : 0

  metadata {
    name      = "${var.name}-secret"
    namespace = var.namespace
  }

  string_data = var.secret_data
}

# In the container spec of kubernetes_deployment "app"
dynamic "env_from" {
  for_each = length(var.secret_data) > 0 ? [1] : []
  content {
    secret_ref {
      name = kubernetes_secret.app_secret[0].metadata[0].name
    }
  }
}
