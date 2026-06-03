#!/usr/bin/env bash
set -euo pipefail

export NODE_NAME="${NODE_NAME:?NODE_NAME is required}"
export NODE_IP="${NODE_IP:?NODE_IP is required}"
export SERVER_1_IP="${SERVER_1_IP:?SERVER_1_IP is required}"
export SERVER_2_IP="${SERVER_2_IP:?SERVER_2_IP is required}"
export SERVER_3_IP="${SERVER_3_IP:?SERVER_3_IP is required}"
export RABBITMQ_PEER_HOST_1="${RABBITMQ_PEER_HOST_1:?RABBITMQ_PEER_HOST_1 is required}"
export RABBITMQ_PEER_HOST_2="${RABBITMQ_PEER_HOST_2:?RABBITMQ_PEER_HOST_2 is required}"
export RABBITMQ_ERLANG_COOKIE="${RABBITMQ_ERLANG_COOKIE:?RABBITMQ_ERLANG_COOKIE is required}"
export RABBITMQ_TLS_CERT_PEM_B64="${RABBITMQ_TLS_CERT_PEM_B64:?RABBITMQ_TLS_CERT_PEM_B64 is required}"
export RABBITMQ_TLS_KEY_PEM_B64="${RABBITMQ_TLS_KEY_PEM_B64:?RABBITMQ_TLS_KEY_PEM_B64 is required}"
RABBITMQ_STARTUP_WAIT_SECONDS="${RABBITMQ_STARTUP_WAIT_SECONDS:-300}"

wait_for_rabbitmq() {
  local deadline=$((SECONDS + RABBITMQ_STARTUP_WAIT_SECONDS))

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if docker compose -f rabbitmq/docker-compose.rabbitmq.yml exec -T rabbitmq rabbitmq-diagnostics -q ping >/dev/null 2>&1; then
      return 0
    fi

    sleep 5
  done

  printf 'Timed out waiting for RabbitMQ node %s to become reachable.\n' "${NODE_NAME}" >&2
  docker compose -f rabbitmq/docker-compose.rabbitmq.yml ps >&2 || true
  docker compose -f rabbitmq/docker-compose.rabbitmq.yml logs --tail=120 rabbitmq >&2 || true
  return 1
}

if [ "${SKIP_FIREWALL:-false}" != "true" ]; then
  bash scripts/apply-firewall.sh
fi

bash scripts/render-rabbitmq-config.sh
bash scripts/prepare-rabbitmq-data-volume.sh

docker compose -f rabbitmq/docker-compose.rabbitmq.yml up -d --remove-orphans
wait_for_rabbitmq

echo "RabbitMQ node ${NODE_NAME} is running. Run scripts/apply-rabbitmq-topology.sh once after all nodes have joined."
