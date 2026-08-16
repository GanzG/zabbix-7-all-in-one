FROM ubuntu:24.04

ARG ZABBIX_VERSION=7.4
ARG POSTGRES_VERSION=16

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt update

RUN apt install -y \
        ca-certificates \
        curl \
        wget \
        gnupg \
        tzdata \
        supervisor \
        nginx \
        postgresql-${POSTGRES_VERSION} \
        postgresql-contrib \
        php-fpm \
        php-pgsql \
        php-gd \
        php-bcmath \
        php-mbstring \
        php-xml \
        php-ldap \
        php-curl \
        php-zip \
        php-json \
        locales && locale-gen en_US.UTF-8

RUN wget -q \
      "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu24.04_all.deb" \
      -O /tmp/zabbix-release.deb \
    && dpkg -i /tmp/zabbix-release.deb \
    && rm -f /tmp/zabbix-release.deb

RUN apt update && apt install -y \
        zabbix-server-pgsql \
        zabbix-sql-scripts \
        zabbix-agent2 \
        zabbix-get

RUN apt install -y \
        zabbix-frontend-php \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
        /run/php \
        /run/postgresql \
        /var/log/supervisor \
        /var/lib/zabbix

RUN cat > /etc/php/8.3/fpm/conf.d/99-zabbix.ini <<'EOF'
post_max_size = 16M
max_execution_time = 300
max_input_time = 300
EOF

RUN cat > /etc/php/8.3/cli/conf.d/99-zabbix.ini <<'EOF'
post_max_size = 16M
max_execution_time = 300
max_input_time = 300
EOF

COPY supervisord.conf /etc/supervisor/conf.d/zabbix.conf
COPY nginx.conf /etc/nginx/sites-enabled/default
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80
EXPOSE 10051

ENV POSTGRES_DB=zabbix
ENV POSTGRES_USER=zabbix
ENV POSTGRES_PORT=5432

ENTRYPOINT ["/entrypoint.sh"]