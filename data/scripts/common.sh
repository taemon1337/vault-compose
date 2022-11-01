#!/bin/bash
VAULT_DIR=${VAULT_DIR:-"/vault"}
VAULT_ADDR=${VAULT_ADDR:-"http://0.0.0.0:8200"}
VAULT_INIT_FILE=${VAULT_INIT_FILE:-"${VAULT_DIR}/file/init-data.txt"}

_vault_init() {
  vault operator init 2>&1 > "${VAULT_INIT_FILE}"
}

_vault_unseal() {
  for token in $(cat "${VAULT_INIT_FILE}" | grep Unseal | awk '{print $4}'); do
    vault operator unseal "${token}"
  done
}

_vault_login() {
  vault login $(cat "${VAULT_INIT_FILE}" | grep Root | awk '{print $4}')
}

_vault_auth_enable() {
  vault auth enable -path=k8s-beta kubernetes
}
