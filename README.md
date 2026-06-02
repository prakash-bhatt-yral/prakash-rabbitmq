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

## Runtime Contract

Prakash connects as a publisher:

```text
amqps://prakash_videogen_publisher:<secret>@<rabbitmq-host>:5671/videogen
```

Vast connects as a consumer:

```text
amqps://vast_ltx_consumer:<secret>@<rabbitmq-host>:5671/videogen
```

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

Render config and deploy on each node:

```bash
NODE_NAME=prakash-1 \
NODE_IP=94.130.13.115 \
SERVER_1_IP=94.130.13.115 \
SERVER_2_IP=88.99.151.102 \
SERVER_3_IP=138.201.129.173 \
RABBITMQ_ERLANG_COOKIE=<shared-cookie> \
RABBITMQ_PUBLISHER_PASSWORD=<secret> \
RABBITMQ_CONSUMER_PASSWORD=<secret> \
RABBITMQ_ADMIN_PASSWORD=<secret> \
RABBITMQ_TLS_CERT_PEM_B64=<base64-pem-cert> \
RABBITMQ_TLS_KEY_PEM_B64=<base64-pem-key> \
bash scripts/deploy-rabbitmq.sh
```

Repeat with the matching `NODE_NAME` and `NODE_IP` on each server.

## Security

- AMQP clients must use TLS in production.
- The management UI must not be public.
- Internode ports are restricted to the three Prakash server IPs.
- Vast worker IPs should be allowed to reach only the AMQPS client port.
- Application users do not get configure permissions; broker topology is loaded
  from definitions managed by this repo.

## References

- RabbitMQ definitions import uses the `definitions.import_backend` and
  `definitions.local.path` config keys in RabbitMQ 3.13+.
