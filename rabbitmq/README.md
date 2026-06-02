# RabbitMQ

This directory contains the deployable RabbitMQ broker configuration.

## Ports

- `5671`: AMQPS clients.
- `15672`: management UI. Keep private.
- `4369`: Erlang port mapper. Cluster-internal only.
- `25672`: Erlang distribution. Cluster-internal only.

## Users

- `prakash_videogen_publisher`: can publish to `videogen.jobs`.
- `vast_ltx_consumer`: can consume from `videogen.ltx.generate`.
- `rabbitmq_admin`: operational access only.

Users and passwords are applied after broker startup with `rabbitmqctl`. They
are not stored in `definitions.json`, because RabbitMQ definitions normally
store password hashes and exported definitions are sensitive.

## Notes

The compose file is intentionally broker-only. Application services should
depend on `RABBITMQ_URL` and should not own RabbitMQ lifecycle.
