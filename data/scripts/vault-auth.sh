#!/bin/sh
CWD=$(dirname $0)
source "${CWD}/common.sh"

_vault_init
_vault_unseal
_vault_login
_vault_auth_enable
_vault_secrets
_vault_demo_role
