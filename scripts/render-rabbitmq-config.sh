#!/usr/bin/env bash
set -euo pipefail

mkdir -p rabbitmq/runtime/tls

cp rabbitmq/rabbitmq.conf.template rabbitmq/runtime/rabbitmq.conf
cp rabbitmq/definitions.json.template rabbitmq/runtime/definitions.json

decode_base64() {
  if base64 --decode < /dev/null >/dev/null 2>&1; then
    base64 --decode
  else
    base64 -D
  fi
}

printf '%s' "${RABBITMQ_TLS_CERT_PEM_B64:?}" | decode_base64 > rabbitmq/runtime/tls/tls.crt
printf '%s' "${RABBITMQ_TLS_KEY_PEM_B64:?}" | decode_base64 > rabbitmq/runtime/tls/tls.key
chmod 644 rabbitmq/runtime/tls/tls.crt rabbitmq/runtime/tls/tls.key
