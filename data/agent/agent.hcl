auto_auth {
  method {
    type = "kubernetes"
    mount_path = "auth/k8s-beta"

    config = {
      role = "star-cert-demo-role"
      token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    }
  }

  sink {
    type = "file"

    config = {
      path = "/vault/agent/vault-token"
    }
  }

  exit_after_auth = false
  pid_file = "/vault/agent/.pid"

  vault {
    address = "http://vault:8200"
    tls_skip_verify = true
  }

}
