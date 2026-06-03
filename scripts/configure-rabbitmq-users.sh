#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-rabbitmq/docker-compose.rabbitmq.yml}"

rabbitmqctl() {
  docker compose -f "${COMPOSE_FILE}" exec -T rabbitmq rabbitmqctl "$@"
}

ensure_user() {
  local user="$1"
  local password="$2"

  if rabbitmqctl list_users | awk '{print $1}' | grep -qx "${user}"; then
    rabbitmqctl change_password "${user}" "${password}"
  else
    rabbitmqctl add_user "${user}" "${password}"
  fi
}

rabbitmqctl delete_user guest >/dev/null 2>&1 || true
rabbitmqctl delete_user disabled >/dev/null 2>&1 || true

ensure_user "prakash_videogen_publisher" "${RABBITMQ_PUBLISHER_PASSWORD:?}"
ensure_user "vast_ltx_consumer" "${RABBITMQ_CONSUMER_PASSWORD:?}"
ensure_user "rabbitmq_admin" "${RABBITMQ_ADMIN_PASSWORD:?}"

rabbitmqctl set_user_tags "prakash_videogen_publisher"
rabbitmqctl set_user_tags "vast_ltx_consumer"
rabbitmqctl set_user_tags "rabbitmq_admin" administrator

rabbitmqctl set_permissions -p /videogen \
  "prakash_videogen_publisher" \
  "" \
  "^videogen\\.jobs$" \
  ""

rabbitmqctl set_permissions -p /videogen \
  "vast_ltx_consumer" \
  "" \
  "" \
  "^videogen\\.ltx\\.generate$"

rabbitmqctl set_permissions -p /videogen \
  "rabbitmq_admin" \
  ".*" \
  ".*" \
  ".*"
