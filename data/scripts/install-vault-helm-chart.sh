#!/bin/sh
CWD=$(dirname $0)
source "${CWD}/common.sh"

if helm get values -n "${VAULT_NAMESPACE}" "${VAULT_HELM_CHART_NAME}" 2>&1 > /dev/null; then
  _info "Helm chart is already installed."
  exit 0
fi

helm repo add hashicorp https://helm.releases.hashicorp.com
helm install "${VAULT_HELM_CHART_NAME}" --create-namespace -n "${VAULT_NAMESPACE}" -f ${HELM_VALUES}/vault-values.yaml hashicorp/vault --version 0.22.1
