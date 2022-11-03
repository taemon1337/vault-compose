#!/bin/sh
CWD=$(dirname $0)
source "${CWD}/common.sh"

VAULT_IP="$1"

if [[ -z "${VAULT_IP}" ]]; then
  echo "Usage: $0 <vault-ip-address>"
  _fail "No vault ip address provided."
fi

cat /vault/config/vault-proxy.yaml | sed "s/VAULT_IP/${VAULT_IP}/g" | kubectl apply -f -

