# prakash-rabbitmq

RabbitMQ infrastructure for Prakash-side services.

This repo owns the RabbitMQ broker used by Prakash to dispatch videogen jobs to
Vast workers. It is intentionally separate from application repos: Prakash
publishes jobs, Vast consumes jobs, and this repo owns broker deployment,
permissions, queue definitions, and operational runbooks.

## Topology

Production target:

```text
prakash-1 94.130.13.115  rabbit@prakash-1
prakash-2 88.99.151.102  rabbit@prakash-2
prakash-3 138.201.129.173 rabbit@prakash-3
```

The videogen queue is a RabbitMQ quorum queue so one broker node can fail
without losing accepted jobs.

RabbitMQ does not use a fixed primary/standby deployment like Patroni. The three
broker nodes are peers. Each quorum queue has an internal Raft leader and
followers; RabbitMQ elects a new queue leader if the current leader node fails.
The deploy workflow therefore starts all nodes as peers and applies topology
after the cluster is reachable, instead of choosing a permanent leader node.

## Runtime Contract

Prakash connects as a publisher:

```text
amqps://prakash_videogen_publisher:<secret>@<rabbitmq-host>:5671/videogen
```

Vast connects as a consumer:

```text
amqps://vast_ltx_consumer:<secret>@<tunnel-amqps-host>:5671/videogen
```

Vast workers do not need stable public IPs. They reach RabbitMQ through the
externally managed named tunnel that runs on the Vast machine. The tunnel is
responsible for exposing RabbitMQ AMQPS to the worker; this repo does not manage
Vast network allowlists. The `vast_ltx_consumer` account is still required:
it is RabbitMQ broker authentication and queue authorization, independent of how
the worker reaches the broker.

The broker does not replace Prakash completion callback authentication. Vast
still signs completion callbacks to Prakash with the HMAC scheme defined in the
videogen migration spec.

## Queue Contract

- vhost: `/videogen`
- exchange: `videogen.jobs`
- routing key: `ltx.generate`
- queue: `videogen.ltx.generate`
- queue type: `quorum`
- publisher: Prakash
- consumer: Vast LTX worker

## Deploy

Manual deploy has two phases:

1. Start each broker node.
2. After all three nodes are reachable, apply topology and users once.

Run deploys as root or as a user with passwordless `sudo iptables` access,
because host firewall rules are applied before Docker publishes RabbitMQ ports.

Start each node with its matching `NODE_NAME` and `NODE_IP`:

```bash
NODE_NAME=prakash-1 \
NODE_IP=94.130.13.115 \
SERVER_1_IP=94.130.13.115 \
SERVER_2_IP=88.99.151.102 \
SERVER_3_IP=138.201.129.173 \
RABBITMQ_ERLANG_COOKIE=<shared-cookie> \
RABBITMQ_TLS_CERT_PEM_B64=<base64-pem-cert> \
RABBITMQ_TLS_KEY_PEM_B64=<base64-pem-key> \
RABBITMQ_DIRECT_AMQPS_CLIENT_IPS="<space-separated-prakash-api-server-ips>" \
bash scripts/deploy-rabbitmq.sh
```

Repeat on `prakash-2` and `prakash-3`.

After all three nodes are running, apply definitions and users once from any
cluster node:

```bash
NODE_NAME=prakash-1 \
SERVER_1_IP=94.130.13.115 \
SERVER_2_IP=88.99.151.102 \
SERVER_3_IP=138.201.129.173 \
RABBITMQ_ERLANG_COOKIE=<shared-cookie> \
RABBITMQ_PUBLISHER_PASSWORD=<secret> \
RABBITMQ_CONSUMER_PASSWORD=<secret> \
RABBITMQ_ADMIN_PASSWORD=<secret> \
bash scripts/apply-rabbitmq-topology.sh
```

The topology step waits for `rabbit@prakash-1`, `rabbit@prakash-2`, and
`rabbit@prakash-3`, imports `definitions.json`, configures users, and verifies
that the quorum queue reports all three members.

The GitHub Actions deploy workflow performs the same sequence automatically:

1. validate config;
2. deploy all three peer nodes with a matrix job;
3. apply topology once from `prakash-1` after every node deploy succeeds.

## Security

- AMQP clients must use TLS in production.
- The management UI is published on host loopback only; use SSH tunneling or a
  private admin path.
- Internode ports are restricted to the three Prakash server IPs.
- Direct Prakash API clients should be allowed to reach only the AMQPS port
  through `RABBITMQ_DIRECT_AMQPS_CLIENT_IPS`.
- Vast workers should reach RabbitMQ through the named tunnel managed on the
  Vast machine.
- Application users do not get configure permissions; broker topology is loaded
  from definitions managed by this repo.
- Publishers must use confirms for accepted-job durability.
- Consumers must use manual acknowledgements so failed jobs are requeued or
  dead-lettered by RabbitMQ.

## Operations

Useful checks:

```bash
bash scripts/validate-rabbitmq-config.sh
docker compose -f rabbitmq/docker-compose.rabbitmq.yml exec -T rabbitmq rabbitmqctl cluster_status
docker compose -f rabbitmq/docker-compose.rabbitmq.yml exec -T rabbitmq rabbitmq-queues quorum_status --vhost /videogen videogen.ltx.generate
docker compose -f rabbitmq/docker-compose.rabbitmq.yml exec -T rabbitmq rabbitmq-diagnostics alarms
```

Credential rotation updates existing RabbitMQ user passwords in place. Roll
application secret changes before rerunning `scripts/apply-rabbitmq-topology.sh`.

## GitHub Actions

The manual deploy workflow expects these secrets:

- `RABBITMQ_DEPLOY_SSH_KEY`
- `RABBITMQ_DEPLOY_USER`
- `RABBITMQ_ERLANG_COOKIE`
- `RABBITMQ_TLS_CERT_PEM_B64`
- `RABBITMQ_TLS_KEY_PEM_B64`
- `RABBITMQ_PUBLISHER_PASSWORD`
- `RABBITMQ_CONSUMER_PASSWORD`
- `RABBITMQ_ADMIN_PASSWORD`

It also reads optional repository variables:

- `RABBITMQ_DIRECT_AMQPS_CLIENT_IPS`: Prakash API server IPs that publish
  directly to RabbitMQ over AMQPS.

## References

- RabbitMQ definitions import uses the `definitions.import_backend` and
  `definitions.local.path` config keys in RabbitMQ 3.13+.
