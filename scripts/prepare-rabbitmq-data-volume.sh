#!/usr/bin/env bash
set -euo pipefail

: "${RABBITMQ_ERLANG_COOKIE:?RABBITMQ_ERLANG_COOKIE is required}"

RABBITMQ_DATA_VOLUME="${RABBITMQ_DATA_VOLUME:-rabbitmq_rabbitmq_data}"
RABBITMQ_IMAGE="${RABBITMQ_IMAGE:-rabbitmq:3.13-management-alpine}"

docker volume create "${RABBITMQ_DATA_VOLUME}" >/dev/null

docker run --rm \
  -e RABBITMQ_ERLANG_COOKIE="${RABBITMQ_ERLANG_COOKIE}" \
  -v "${RABBITMQ_DATA_VOLUME}:/var/lib/rabbitmq" \
  "${RABBITMQ_IMAGE}" \
  sh -c '
    set -e
    if [ ! -f /var/lib/rabbitmq/.erlang.cookie ]; then
      printf "%s" "${RABBITMQ_ERLANG_COOKIE}" > /var/lib/rabbitmq/.erlang.cookie
    fi
    chown -R rabbitmq:rabbitmq /var/lib/rabbitmq
    chmod 700 /var/lib/rabbitmq
    chmod 400 /var/lib/rabbitmq/.erlang.cookie
  '
