#!/bin/sh
VAULT_DIR=${VAULT_DIR:-"/vault"}
AUTH_MOUNT=${AUTH_MOUNT:-"k8s"}
CONF_DIR=${VAULT_DIR}/config
CERT_DIR=${VAULT_DIR}/certs
DEBUG=${DEBUG:-1}
DOMAIN=${DOMAIN:-"${AUTH_MOUNT}.local"}
HELM_VALUES=${CONF_DIR}
KUBE_HOST=${KUBE_HOST:-""}
STAR_CERT_FILE=${STAR_CERT_FILE:-"${CERT_DIR}/star-cert.crt"}
STAR_CERT_KEY_FILE=${STAR_CERT_KEY_FILE:-"${CERT_DIR}/star-cert.key"}
STAR_CERT_SAN=${STAR_CERT_SAN:-"*.${DOMAIN}"}
STAR_CERT_TTL=${STAR_CERT_TTL:-"8760h"}
STAR_CERT_POLICY=${STAR_CERT_POLICY:-"star-cert-policy"}
STAR_CERT_POLICY_FILE=${STAR_CERT_POLICY_FILE:-"${CONF_DIR}/star-cert-policy.hcl"}
CA_CERT_FILE=${CA_CERT_FILE:-"${CERT_DIR}/ca.crt"}
CA_KEY_FILE=${CA_KEY_FILE:-"${CERT_DIR}/ca.key"}
VAULT_ENV=${CONF_DIR}/vault.env
VAULT_ADDR=${VAULT_ADDR:-"http://0.0.0.0:8200"}
VAULT_INIT_FILE=${VAULT_INIT_FILE:-"${VAULT_DIR}/file/init-data.txt"}
VAULT_NAMESPACE=${VAULT_NAMESPACE:-"vault"}
VAULT_HELM_CHART_NAME=${VAULT_HELM_CHART_NAME:-"vault-injector"}
VAULT_AUTH_SERVICE_ACCOUNT=${VAULT_AUTH_SERVICE_ACCOUNT:-"${VAULT_HELM_CHART_NAME}"}
VAULT_SECRET_PATH=${VAULT_SECRET_PATH:-"certs"}

_info() {
  if [[ -n "${DEBUG}" ]]; then
    echo "[INFO] ${@}"
  fi
}

_fail() {
  echo "[ERROR] ${@}"
  exit 1
}

_vault_status() {
  vault status
}

_vault_initialized() {
  _vault_status | grep Initialized | awk '{print $2}'
}

_vault_sealed() {
  _vault_status | grep Sealed | awk '{print $2}'
}

_vault_init() {
  local initialized="$(_vault_initialized)"
  if [[ "${initialized}" == "false" ]]; then
    _info "initializing vault"
    vault operator init 2>&1 > "${VAULT_INIT_FILE}"
  fi
}

_vault_unseal() {
  local sealed="$(_vault_sealed)"
  if [[ "${sealed}" == "true" ]]; then
    _info "unsealing vault"
    for token in $(cat "${VAULT_INIT_FILE}" | grep Unseal | awk '{print $4}'); do
      vault operator unseal "${token}"
      sealed="$(_vault_sealed)"
      if [[ "${sealed}" == "false" ]]; then
        _info "unsealed vault"
        return
      fi
    done
  fi
}

_vault_login() {
  export VAULT_TOKEN=$(cat "${VAULT_INIT_FILE}" | grep Root | awk '{print $4}')
}

_vault_auth_enable() {
  local found=$(vault auth list | grep k8s/ | awk '{print $1}')
  if [[ "${found}" == "${AUTH_MOUNT}/" ]]; then
    _info "Vault auth/${AUTH_MOUNT} is aleady configured."
  else
    vault auth enable -path=${AUTH_MOUNT} kubernetes
  fi

  _info "Loading vault environment"
  . "${VAULT_ENV}"

  if [[ -z "${AUTH_MOUNT}" ]]; then _fail "AUTH_MOUNT not set."; fi
  if [[ -z "${KUBE_CA_CERT}" ]]; then _fail "KUBE_CA_CERT not set."; fi
  if [[ -z "${KUBE_HOST}" ]]; then _fail "KUBE_HOST not set."; fi
  if [[ -z "${TOKEN_REVIEW_JWT}" ]]; then _fail "TOKEN_REVIEW_JWT not set."; fi

  vault write auth/${AUTH_MOUNT}/config \
    kubernetes_host="${KUBE_HOST}" \
    kubernetes_ca_cert="${KUBE_CA_CERT}" \
    token_reviewer_jwt="${TOKEN_REVIEW_JWT}" \
    disable_local_ca_jwt=true
}

_vault_secrets() {
  local found=$(vault secrets list | grep "${VAULT_SECRET_PATH}/" | awk '{print $1}')
  if [[ "${found}" == "${VAULT_SECRET_PATH}/" ]]; then
    _info "vault secret backend already enabled at ${VAULT_SECRET_PATH}"
  else
    vault secrets enable -path=${VAULT_SECRET_PATH} kv-v2
  fi

  vault kv put -mount="${VAULT_SECRET_PATH}" star-cert tls.crt="@${STAR_CERT_FILE}"
  vault kv patch -mount="${VAULT_SECRET_PATH}" star-cert tls.key="@${STAR_CERT_KEY_FILE}"
  vault kv get -format=json "${VAULT_SECRET_PATH}/star-cert"
}

_vault_policies() {
  local found=$(vault policy list | grep "${STAR_CERT_POLICY}")
  if [[ "${found}" == "${STAR_CERT_POLICY}" ]]; then
    _info "vault policy ${STAR_CERT_POLICY} already created."
  else
    vault policy write "${STAR_CERT_POLICY}" "${STAR_CERT_POLICY_FILE}"
  fi

  vault policy read "${STAR_CERT_POLICY}"
}

_set_vault_env() {
  if ! command -v kubectl 2>&1 > /dev/null; then
    _fail "_set_vault_env required 'kubectl' but none detected."
  fi

# TOKEN_REVIEW_JWT=$(kubectl get secret -n vault-infra vault-auth -o go-template='{{ .data.token }}' | base64 --decode)
  local jwt=$(kubectl create token -n "${VAULT_NAMESPACE}" "${VAULT_AUTH_SERVICE_ACCOUNT}")
  local ca=$(kubectl config view -n "${VAULT_NAMESPACE}" --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
  local host=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

  echo export TOKEN_REVIEW_JWT=\"${jwt}\" > "${VAULT_ENV}"
  echo export KUBE_CA_CERT=\"${ca//$'\n'/\\n}\" >> "${VAULT_ENV}"
  echo export KUBE_HOST="${host}" >> "${VAULT_ENV}"
}

_vault_demo_role() {
  vault write auth/${AUTH_MOUNT}/role/star-cert-demo-role \
    bound_service_account_names=vault-demo \
    bound_service_account_namespaces=demo \
    policies=star-cert-policy \
    ttl=1440h
}

_generate_ca_certs() {
  if [[ -f "${CA_CERT_FILE}" ]] && [[ -f "${CA_KEY_FILE}" ]]; then
    _info "ca certs already generated"
    return
  fi

  step certificate create "root.${DOMAIN}" "${CA_CERT_FILE}" "${CA_KEY_FILE}" --profile root-ca --no-password --insecure
  step certificate inspect --short "${CA_CERT_FILE}"
}

_generate_certs() {
  if [[ -f "${STAR_CERT_FILE}" ]] && [[ -f "${STAR_CERT_KEY_FILE}" ]]; then
    _info "star cert already generated"
    return
  fi

  step certificate create star-cert "${STAR_CERT_FILE}" "${STAR_CERT_KEY_FILE}" \
    --san "${STAR_CERT_SAN}" --not-after "${STAR_CERT_TTL}" \
    --no-password --insecure \
    --ca "${CA_CERT_FILE}" --ca-key "${CA_KEY_FILE}"

  step certificate inspect --short "${STAR_CERT_FILE}"
}
