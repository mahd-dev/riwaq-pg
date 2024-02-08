FROM paradedb/paradedb:latest

ENV POSTGIS_MAJOR 3
ENV CITUS_VERSION 12.1.1.citus-1

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
    && curl -s https://install.citusdata.com/community/deb.sh | bash \
    && apt-get install -y postgresql-$PG_MAJOR-citus-12.1=$CITUS_VERSION \
                          postgresql-$PG_MAJOR-hll=2.18.citus-1 \
                          postgresql-$PG_MAJOR-topn=2.6.0.citus-1 \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /docker-entrypoint-initdb.d

COPY ./docker/init-db/initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./docker/init-db/update-postgis.sh /usr/local/bin

RUN echo "shared_preload_libraries='citus'" >> /usr/share/postgresql/postgresql.conf.sample
COPY ./docker/init-db/001-create-citus-extension.sql /docker-entrypoint-initdb.d/
COPY ./docker/init-db/pg_healthcheck ./docker/init-db/wait-for-manager.sh /
RUN chmod +x /wait-for-manager.sh
RUN chmod +x /docker-entrypoint-initdb.d/10_postgis.sh

# entry point unsets PGPASSWORD, but we need it to connect to workers
# https://github.com/docker-library/postgres/blob/33bccfcaddd0679f55ee1028c012d26cd196537d/12/docker-entrypoint.sh#L303
RUN sed "/unset PGPASSWORD/d" -i /usr/local/bin/docker-entrypoint.sh
HEALTHCHECK --interval=4s --start-period=6s CMD ./pg_healthcheck
