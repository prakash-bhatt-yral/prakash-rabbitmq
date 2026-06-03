# RabbitMQ

This directory contains the deployable RabbitMQ broker configuration.

## Ports

- `5671`: AMQPS clients.
- `15672`: management UI. Published on host loopback only.
- `4369`: Erlang port mapper. Cluster-internal only.
- `25672`: Erlang distribution. Cluster-internal only.

## Users

- `prakash_videogen_publisher`: can publish to `videogen.jobs`.
- `vast_ltx_consumer`: can consume from `videogen.ltx.generate`. This user is
  the broker credential used by the Vast worker through its externally managed
  tunnel; it is not a public IP allowlist.
- `rabbitmq_admin`: operational access only.

Topology is imported after all three nodes are reachable so quorum queues are
declared with the intended replica set. Users and passwords are applied after
that import with `rabbitmqctl`. Users are not stored in `definitions.json`,
because RabbitMQ definitions normally store password hashes and exported
definitions are sensitive.

## Notes

The compose file is intentionally broker-only. Application services should
depend on `RABBITMQ_URL` and should not own RabbitMQ lifecycle.

The firewall is applied on the host before Docker starts the broker. The compose
file does not run a privileged firewall sidecar. Run deployment as root or with
passwordless `sudo iptables` access.
