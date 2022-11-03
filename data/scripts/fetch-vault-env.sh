#!/bin/bash
CWD=$(dirname $0)
source "${CWD}/common.sh"

_set_vault_env
cat "${VAULT_ENV}"
