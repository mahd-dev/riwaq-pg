#!/bin/bash
# wait-for-manager.sh

set -e

until test -f /healthcheck/manager-ready ; do
  >&2 echo "Manager is not ready - sleeping"
  sleep 1
done

>&2 echo "Manager is up - starting worker"

exec gosu postgres "/usr/local/bin/docker-entrypoint.sh" "postgres" "-c" "wal_level=logical" "-c" "max_wal_senders=10" "-c" "max_replication_slots=10" "-c" "log_min_messages=fatal"
