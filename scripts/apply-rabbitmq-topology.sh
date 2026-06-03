#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-rabbitmq/docker-compose.rabbitmq.yml}"
RABBITMQ_CLUSTER_NODES="${RABBITMQ_CLUSTER_NODES:-rabbit@prakash-1 rabbit@prakash-2 rabbit@prakash-3}"
RABBITMQ_CLUSTER_WAIT_SECONDS="${RABBITMQ_CLUSTER_WAIT_SECONDS:-600}"

: "${NODE_NAME:?NODE_NAME is required}"
: "${SERVER_1_IP:?SERVER_1_IP is required}"
: "${SERVER_2_IP:?SERVER_2_IP is required}"
: "${SERVER_3_IP:?SERVER_3_IP is required}"
: "${RABBITMQ_PEER_HOST_1:?RABBITMQ_PEER_HOST_1 is required}"
: "${RABBITMQ_PEER_HOST_2:?RABBITMQ_PEER_HOST_2 is required}"
: "${RABBITMQ_ERLANG_COOKIE:?RABBITMQ_ERLANG_COOKIE is required}"
: "${RABBITMQ_PUBLISHER_PASSWORD:?RABBITMQ_PUBLISHER_PASSWORD is required}"
: "${RABBITMQ_CONSUMER_PASSWORD:?RABBITMQ_CONSUMER_PASSWORD is required}"
: "${RABBITMQ_ADMIN_PASSWORD:?RABBITMQ_ADMIN_PASSWORD is required}"

rabbitmqctl() {
  docker compose -f "${COMPOSE_FILE}" exec -T rabbitmq rabbitmqctl "$@"
}

rabbitmq_diagnostics() {
  docker compose -f "${COMPOSE_FILE}" exec -T rabbitmq rabbitmq-diagnostics "$@"
}

rabbitmq_queues() {
  docker compose -f "${COMPOSE_FILE}" exec -T rabbitmq rabbitmq-queues "$@"
}

wait_for_cluster() {
  local deadline=$((SECONDS + RABBITMQ_CLUSTER_WAIT_SECONDS))
  local node

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    local all_running=true
    local cluster_status

    # shellcheck disable=SC2086
    for node in ${RABBITMQ_CLUSTER_NODES}; do
      if ! rabbitmq_diagnostics -q -n "${node}" ping >/dev/null 2>&1; then
        all_running=false
        break
      fi
    done

    if [ "${all_running}" = "true" ]; then
      cluster_status="$(rabbitmqctl cluster_status 2>/dev/null || true)"

      # shellcheck disable=SC2086
      for node in ${RABBITMQ_CLUSTER_NODES}; do
        if ! printf '%s\n' "${cluster_status}" | grep -Fq "${node}"; then
          all_running=false
          break
        fi
      done
    fi

    if [ "${all_running}" = "true" ]; then
      return 0
    fi

    sleep 10
  done

  echo "Timed out waiting for RabbitMQ cluster nodes: ${RABBITMQ_CLUSTER_NODES}" >&2
  rabbitmqctl cluster_status >&2 || true
  exit 1
}

verify_quorum_membership() {
  local status
  local node

  status="$(rabbitmq_queues quorum_status --vhost /videogen videogen.ltx.generate)"

  # shellcheck disable=SC2086
  for node in ${RABBITMQ_CLUSTER_NODES}; do
    if ! printf '%s\n' "${status}" | grep -Fq "${node}"; then
      echo "Queue videogen.ltx.generate does not report quorum member ${node}" >&2
      printf '%s\n' "${status}" >&2
      exit 1
    fi
  done
}

rabbitmqctl await_startup --timeout 300
wait_for_cluster

rabbitmqctl import_definitions /etc/rabbitmq/definitions.json
bash scripts/configure-rabbitmq-users.sh
verify_quorum_membership

echo "RabbitMQ topology, users, permissions, and quorum membership are applied."
