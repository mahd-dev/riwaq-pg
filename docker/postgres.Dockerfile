FROM paradedb/paradedb:latest

ENV POSTGIS_MAJOR 3

USER root

RUN apt update \
    && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
    && apt install -y --no-install-recommends \
    postgresql-$PG_MAJOR-wal2json \
    postgresql-contrib \
    ca-certificates \
    postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
    postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
    && rm -rf /var/lib/apt/lists/*
