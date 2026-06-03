#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if ! grep -Eq "$pattern" "$file"; then
    fail "${description}"
  fi
}

require_not_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "${description}"
  fi
}

bash -n \
  scripts/deploy-rabbitmq.sh \
  scripts/apply-rabbitmq-topology.sh \
  scripts/configure-rabbitmq-users.sh \
  scripts/prepare-rabbitmq-data-volume.sh \
  scripts/write-deploy-ssh-key.sh \
  scripts/render-rabbitmq-config.sh
bash -n scripts/apply-firewall.sh

jq . rabbitmq/definitions.json.template >/dev/null
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' \
  .github/workflows/deploy-rabbitmq.yml \
  .github/workflows/validate-rabbitmq.yml

NODE_NAME=prakash-1 \
NODE_IP=94.130.13.115 \
SERVER_1_IP=94.130.13.115 \
SERVER_2_IP=88.99.151.102 \
SERVER_3_IP=138.201.129.173 \
RABBITMQ_PEER_HOST_1=prakash-2:88.99.151.102 \
RABBITMQ_PEER_HOST_2=prakash-3:138.201.129.173 \
RABBITMQ_ERLANG_COOKIE=dummy \
docker compose -f rabbitmq/docker-compose.rabbitmq.yml config --quiet

require_not_contains rabbitmq/rabbitmq.conf.template '^loopback_users\.guest[[:space:]]*=[[:space:]]*false' \
  'guest user must not be remotely enabled'
require_not_contains rabbitmq/rabbitmq.conf.template '^default_user[[:space:]]*=' \
  'default users must not be configured in rabbitmq.conf'
require_not_contains rabbitmq/rabbitmq.conf.template '^definitions\.' \
  'definitions must be imported after cluster formation, not at boot'

require_not_contains rabbitmq/docker-compose.rabbitmq.yml '^[[:space:]]+firewall:' \
  'firewall must be applied before compose starts, not as a sidecar'
require_not_contains rabbitmq/docker-compose.rabbitmq.yml 'privileged:[[:space:]]*true' \
  'compose must not run a privileged firewall sidecar'
require_contains rabbitmq/docker-compose.rabbitmq.yml '127\.0\.0\.1:15672:15672' \
  'management UI must only publish on host loopback'
require_contains rabbitmq/docker-compose.rabbitmq.yml '\$\{RABBITMQ_ERLANG_COOKIE:\?' \
  'compose must enforce required Erlang cookie env var'
require_contains rabbitmq/docker-compose.rabbitmq.yml '\$\{RABBITMQ_PEER_HOST_1:\?' \
  'compose must require a first peer host mapping'
require_contains rabbitmq/docker-compose.rabbitmq.yml '\$\{RABBITMQ_PEER_HOST_2:\?' \
  'compose must require a second peer host mapping'
require_not_contains rabbitmq/docker-compose.rabbitmq.yml '"prakash-1:\$\{SERVER_1_IP' \
  'compose must not map the local node name to its public IP on every node'

require_contains scripts/configure-rabbitmq-users.sh 'change_password "\$\{user\}" "\$\{password\}"' \
  'existing user passwords must be rotated with rabbitmqctl change_password'
require_contains scripts/configure-rabbitmq-users.sh 'add_user "\$\{user\}" "\$\{password\}"' \
  'new users must be created with RabbitMQ documented add_user username password form'

require_contains scripts/deploy-rabbitmq.sh 'scripts/apply-firewall\.sh' \
  'deploy must apply host firewall before compose up'
require_contains scripts/deploy-rabbitmq.sh 'SERVER_1_IP.*SERVER_1_IP is required' \
  'deploy must enforce required server IP env vars for firewall setup'
require_contains scripts/deploy-rabbitmq.sh 'scripts/prepare-rabbitmq-data-volume\.sh' \
  'deploy must prepare RabbitMQ data volume ownership before compose up'
require_not_contains scripts/deploy-rabbitmq.sh 'RABBITMQ_PUBLISHER_PASSWORD' \
  'node deploy must not require application user passwords'
require_contains scripts/apply-firewall.sh 'RABBITMQ_DIRECT_AMQPS_CLIENT_IPS' \
  'firewall must support explicit direct Prakash AMQPS client IP allowlisting'
old_direct_client_env='RABBITMQ_CLIENT''_IPS'
require_not_contains scripts/apply-firewall.sh "${old_direct_client_env}" \
  'firewall must use the explicit direct Prakash AMQPS client IP env name'
require_not_contains .github/workflows/deploy-rabbitmq.yml "${old_direct_client_env}" \
  'deploy workflow must use the explicit direct Prakash AMQPS client IP env name'
obsolete_vast_network_env='VAST_WORKER''_IPS'
require_not_contains scripts/apply-firewall.sh "${obsolete_vast_network_env}" \
  'Vast network allowlisting must not be managed by this broker firewall'
require_not_contains .github/workflows/deploy-rabbitmq.yml "${obsolete_vast_network_env}" \
  'deploy workflow must not require Vast network allowlisting'
require_not_contains README.md "${obsolete_vast_network_env}" \
  'README must not document Vast network allowlisting'
require_contains README.md 'named tunnel' \
  'README must document Vast named tunnel access'
require_contains scripts/apply-rabbitmq-topology.sh 'import_definitions /etc/rabbitmq/definitions\.json' \
  'topology must import definitions after cluster formation'
require_contains scripts/apply-rabbitmq-topology.sh 'cluster_status' \
  'topology apply must verify RabbitMQ cluster status before import'
require_contains scripts/apply-rabbitmq-topology.sh 'quorum_status --vhost /videogen videogen\.ltx\.generate' \
  'topology apply must verify quorum queue membership'
require_contains rabbitmq/definitions.json.template '"x-quorum-initial-group-size": 3' \
  'quorum queues must declare a three-node initial group size'

require_contains .github/workflows/deploy-rabbitmq.yml 'workflow_dispatch:' \
  'deploy workflow must be manually runnable'
require_not_contains .github/workflows/deploy-rabbitmq.yml 'Placeholder|placeholder' \
  'deploy workflow must not be a placeholder'
require_not_contains .github/workflows/deploy-rabbitmq.yml 'inputs:' \
  'deploy workflow must not require per-node manual inputs'
require_contains .github/workflows/deploy-rabbitmq.yml 'matrix:' \
  'deploy workflow must deploy RabbitMQ nodes with a matrix'
require_contains .github/workflows/deploy-rabbitmq.yml 'apply-topology:' \
  'deploy workflow must apply topology once after all nodes deploy'
require_contains .github/workflows/deploy-rabbitmq.yml 'needs: deploy' \
  'topology job must wait for all matrix deploys'
require_contains .github/workflows/deploy-rabbitmq.yml 'bash -se' \
  'deploy workflow SSH commands must explicitly run remote bash'
require_contains .github/workflows/deploy-rabbitmq.yml 'scripts/write-deploy-ssh-key\.sh' \
  'deploy workflow must normalize and validate the SSH private key before scp'
require_contains .github/workflows/validate-rabbitmq.yml 'pull_request:' \
  'validation workflow must run on pull requests'
require_contains .github/workflows/validate-rabbitmq.yml 'shellcheck' \
  'validation workflow must run ShellCheck in CI'

printf 'RabbitMQ config validation passed.\n'
