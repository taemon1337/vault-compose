#!/bin/bash
CWD=$(dirname $0)
source "${CWD}/common.sh"

_generate_ca_certs
_generate_certs
