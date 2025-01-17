FROM postgres:17

RUN apt-get update \
    && apt-get install -y postgresql-14-postgis-3.5 \
    && apt-get install -y pg_analytics


CMD ["/usr/local/bin/docker-entrypoint.sh","postgres"]