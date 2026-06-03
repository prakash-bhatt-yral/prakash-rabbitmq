#!/usr/bin/env bash
set -euo pipefail

export NODE_NAME="${NODE_NAME:?NODE_NAME is required}"
export NODE_IP="${NODE_IP:?NODE_IP is required}"
export SERVER_1_IP="${SERVER_1_IP:?SERVER_1_IP is required}"
export SERVER_2_IP="${SERVER_2_IP:?SERVER_2_IP is required}"
export SERVER_3_IP="${SERVER_3_IP:?SERVER_3_IP is required}"
export RABBITMQ_ERLANG_COOKIE="${RABBITMQ_ERLANG_COOKIE:?RABBITMQ_ERLANG_COOKIE is required}"
export RABBITMQ_TLS_CERT_PEM_B64="${RABBITMQ_TLS_CERT_PEM_B64:?RABBITMQ_TLS_CERT_PEM_B64 is required}"
export RABBITMQ_TLS_KEY_PEM_B64="${RABBITMQ_TLS_KEY_PEM_B64:?RABBITMQ_TLS_KEY_PEM_B64 is required}"

if [ "${SKIP_FIREWALL:-false}" != "true" ]; then
  bash scripts/apply-firewall.sh
fi

bash scripts/render-rabbitmq-config.sh

docker compose -f rabbitmq/docker-compose.rabbitmq.yml up -d --remove-orphans
docker compose -f rabbitmq/docker-compose.rabbitmq.yml exec -T rabbitmq rabbitmqctl await_startup --timeout 300

echo "RabbitMQ node ${NODE_NAME} is running. Run scripts/apply-rabbitmq-topology.sh once after all nodes have joined."
