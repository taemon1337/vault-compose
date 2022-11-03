# Vault Compose

This project uses `k3d` and `docker-compose` to build an external Vault
connected to Kubernetes and use the vault injector to attempt to load secrets
from Vault into Kubernetes.

## Getting Started

```
  # clone this repo
  git clone git@github.com:taemon1337/vault-compose.git

  # change into repo directory
  cd vault-compose

  # export your host IP address
  export HOST_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')

  # build project
  make build

  # show vault agent logs
  kubectl logs -n demo -f $(kubectl get pods -n demo | tail -n 1 | awk '{print $1}') vault-agent-init
```

