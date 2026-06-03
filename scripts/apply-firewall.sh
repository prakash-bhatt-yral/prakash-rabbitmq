#!/usr/bin/env bash
set -euo pipefail

: "${SERVER_1_IP:?SERVER_1_IP is required}"
: "${SERVER_2_IP:?SERVER_2_IP is required}"
: "${SERVER_3_IP:?SERVER_3_IP is required}"

RABBITMQ_DIRECT_AMQPS_CLIENT_IPS="${RABBITMQ_DIRECT_AMQPS_CLIENT_IPS:-}"
CHAIN="${RABBITMQ_FIREWALL_CHAIN:-RABBITMQ-FILTER}"
EXT_IF="${EXT_IF:-$(ip -4 route show default | awk '{print $5; exit}')}"

if [ -z "${EXT_IF}" ]; then
  echo "Unable to detect default external interface. Set EXT_IF explicitly." >&2
  exit 1
fi

IPTABLES_BIN="${IPTABLES_BIN:-$(command -v iptables || true)}"
if [ -z "${IPTABLES_BIN}" ] && [ -x /usr/sbin/iptables ]; then
  IPTABLES_BIN="/usr/sbin/iptables"
fi

if [ -z "${IPTABLES_BIN}" ]; then
  echo "iptables is required to apply RabbitMQ firewall rules." >&2
  exit 1
fi

IPTABLES=("${IPTABLES_BIN}")
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Run as root or install sudo with passwordless iptables access." >&2
    exit 1
  fi

  IPTABLES=(sudo -n "${IPTABLES_BIN}")
fi

"${IPTABLES[@]}" -N DOCKER-USER 2>/dev/null || true
"${IPTABLES[@]}" -N "${CHAIN}" 2>/dev/null || true
"${IPTABLES[@]}" -F "${CHAIN}"

while "${IPTABLES[@]}" -D DOCKER-USER -i "${EXT_IF}" -j "${CHAIN}" 2>/dev/null; do
  :
done

"${IPTABLES[@]}" -I DOCKER-USER 1 -i "${EXT_IF}" -j "${CHAIN}"

allow_tcp() {
  local port="$1"
  local source_ip="$2"

  "${IPTABLES[@]}" -A "${CHAIN}" -p tcp --dport "${port}" -s "${source_ip}" -j ACCEPT
}

for server_ip in "${SERVER_1_IP}" "${SERVER_2_IP}" "${SERVER_3_IP}"; do
  allow_tcp 5671 "${server_ip}"
  allow_tcp 4369 "${server_ip}"
  allow_tcp 25672 "${server_ip}"
done

# shellcheck disable=SC2086
for client_ip in ${RABBITMQ_DIRECT_AMQPS_CLIENT_IPS}; do
  allow_tcp 5671 "${client_ip}"
done

"${IPTABLES[@]}" -A "${CHAIN}" -p tcp --dport 5671 -j DROP
"${IPTABLES[@]}" -A "${CHAIN}" -p tcp --dport 4369 -j DROP
"${IPTABLES[@]}" -A "${CHAIN}" -p tcp --dport 25672 -j DROP
"${IPTABLES[@]}" -A "${CHAIN}" -j RETURN

echo "RabbitMQ firewall rules applied on ${EXT_IF} via ${CHAIN}"
