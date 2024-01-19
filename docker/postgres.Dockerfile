FROM postgres:alpine

RUN apk add --no-cache git make gcc build-base clang15 llvm15 postgis \
    && git clone https://github.com/eulerto/wal2json.git \
    && cd wal2json \
    && USE_PGXS=1 make \
    && USE_PGXS=1 make install \
    && apk del git make gcc build-base clang15 llvm15 && apk cache clean \
    && cd .. && rm -rf wal2json

# ################### install postgis ##################

ENV POSTGIS_VERSION "refs/tags/3.4.1"

RUN set -eux \
    && apk add --no-cache --virtual .fetch-deps \
        ca-certificates \
        openssl \
        tar \
    \
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz" \
    && mkdir -p /usr/src/postgis \
    && tar \
        --extract \
        --file postgis.tar.gz \
        --directory /usr/src/postgis \
        --strip-components 1 \
    && rm postgis.tar.gz \
    \
    && apk add --no-cache --virtual .build-deps \
        \
        gdal-dev \
        geos-dev \
        proj-dev \
        proj-util \
        sfcgal-dev \
        \
        # The upstream variable, '$DOCKER_PG_LLVM_DEPS' contains
        #  the correct versions of 'llvm-dev' and 'clang' for the current version of PostgreSQL.
        # This improvement has been discussed in https://github.com/docker-library/postgres/pull/1077
        $DOCKER_PG_LLVM_DEPS \
        \
        autoconf \
        automake \
        cunit-dev \
        file \
        g++ \
        gcc \
        gettext-dev \
        git \
        json-c-dev \
        libtool \
        libxml2-dev \
        make \
        pcre2-dev \
        perl \
        protobuf-c-dev \
    \
# build PostGIS - with Link Time Optimization (LTO) enabled
    && cd /usr/src/postgis \
    && gettextize \
    && ./autogen.sh \
    && ./configure \
        --enable-lto \
    && make -j$(nproc) \
    && make install \
    \
# This section is for refreshing the proj data for the regression tests.
# It serves as a workaround for an issue documented at https://trac.osgeo.org/postgis/ticket/5316
# This increases the Docker image size by about 1 MB.
    && projsync --system-directory --file ch_swisstopo_CHENyx06_ETRS \
    && projsync --system-directory --file us_noaa_eshpgn \
    && projsync --system-directory --file us_noaa_prvi \
    && projsync --system-directory --file us_noaa_wmhpgn \
# This section performs a regression check.
    && mkdir /tempdb \
    && chown -R postgres:postgres /tempdb \
    && su postgres -c 'pg_ctl -D /tempdb init' \
    && su postgres -c 'pg_ctl -D /tempdb -c -l /tmp/logfile -o '-F' start ' \
    && cd regress \
    && make -j$(nproc) check RUNTESTFLAGS=--extension   PGUSER=postgres \
    \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS postgis;"' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;"' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;"' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch; --needed for postgis_tiger_geocoder "' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS address_standardizer;"' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;"' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;"' \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"' \
    && su postgres -c 'psql -t -c "SELECT version();"'              >> /_pgis_full_version.txt \
    && su postgres -c 'psql -t -c "SELECT PostGIS_Full_Version();"' >> /_pgis_full_version.txt \
    && su postgres -c 'psql -t -c "\dx"' >> /_pgis_full_version.txt \
    \
    && su postgres -c 'pg_ctl -D /tempdb --mode=immediate stop' \
    && rm -rf /tempdb \
    && rm -rf /tmp/logfile \
    && rm -rf /tmp/pgis_reg \
# add .postgis-rundeps
    && apk add --no-cache --virtual .postgis-rundeps \
        \
        gdal \
        geos \
        proj \
        sfcgal \
        \
        json-c \
        libstdc++ \
        pcre2 \
        protobuf-c \
        \
        # ca-certificates: for accessing remote raster files
        #   fix https://github.com/postgis/docker-postgis/issues/307
        ca-certificates \
# clean
    && cd / \
    && rm -rf /usr/src/postgis \
    && apk del .fetch-deps .build-deps \
# At the end of the build, we print the collected information
# from the '/_pgis_full_version.txt' file. This is for experimental and internal purposes.
    && cat /_pgis_full_version.txt
