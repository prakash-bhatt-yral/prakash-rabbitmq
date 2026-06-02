#!/bin/sh
set -e

EXT_IF=$(ip -4 route show default | awk '{print $5; exit}')

allow_cluster_port() {
  PORT="$1"
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -j DROP 2>/dev/null || true
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_1_IP" -j ACCEPT 2>/dev/null || true
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_2_IP" -j ACCEPT 2>/dev/null || true
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_3_IP" -j ACCEPT 2>/dev/null || true

  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_1_IP" -j ACCEPT
  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_2_IP" -j ACCEPT
  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_3_IP" -j ACCEPT
  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -j DROP
}

allow_client_port() {
  PORT="$1"
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -j DROP 2>/dev/null || true
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_1_IP" -j ACCEPT 2>/dev/null || true
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_2_IP" -j ACCEPT 2>/dev/null || true
  iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_3_IP" -j ACCEPT 2>/dev/null || true

  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_1_IP" -j ACCEPT
  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_2_IP" -j ACCEPT
  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$SERVER_3_IP" -j ACCEPT

  for IP in $VAST_WORKER_IPS; do
    iptables -D DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$IP" -j ACCEPT 2>/dev/null || true
    iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -s "$IP" -j ACCEPT
  done

  iptables -A DOCKER-USER -p tcp -i "$EXT_IF" --dport "$PORT" -j DROP
}

allow_client_port 5671
allow_cluster_port 4369
allow_cluster_port 25672
allow_cluster_port 15672

echo "RabbitMQ firewall rules applied on ${EXT_IF}"
exec sleep infinity
