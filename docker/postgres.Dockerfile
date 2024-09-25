FROM paradedb/paradedb:latest

ENV PG_MAJOR 16
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
    curl \
    && apt-get purge -y \
    && rm -rf /var/lib/apt/lists/*
