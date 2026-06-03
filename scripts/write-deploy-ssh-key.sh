#!/usr/bin/env bash
set -euo pipefail

target_path="${1:-${HOME}/.ssh/rabbitmq_deploy}"

: "${RABBITMQ_DEPLOY_SSH_KEY:?RABBITMQ_DEPLOY_SSH_KEY is required}"

mkdir -p "$(dirname "${target_path}")"
umask 077

key_material="${RABBITMQ_DEPLOY_SSH_KEY//$'\r'/}"

if [[ "${key_material}" == *'\n'* ]]; then
  key_material="${key_material//\\n/$'\n'}"
fi

if [[ "${key_material}" == *"-----BEGIN "*"PRIVATE KEY-----"* ]]; then
  printf '%s\n' "${key_material}" > "${target_path}"
else
  if ! printf '%s' "${key_material}" | base64 --decode > "${target_path}" 2>/dev/null; then
    echo "RABBITMQ_DEPLOY_SSH_KEY must be a private key or a base64-encoded private key." >&2
    exit 1
  fi
fi

chmod 600 "${target_path}"

if ! ssh-keygen -y -f "${target_path}" >/dev/null 2>&1; then
  echo "RABBITMQ_DEPLOY_SSH_KEY is not a parseable private key." >&2
  echo "Store the unencrypted private key, not the public key. Multiline, escaped-newline, and base64-encoded private keys are accepted." >&2
  exit 1
fi
