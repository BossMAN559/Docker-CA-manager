FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DATA_DIR=/data/ca
ENV WWW_DIR=/var/www/html

# install packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    php-fpm \
    php-cli \
    php-xml \
    php-mbstring \
    openssl \
    supervisor \
    pwgen \
    unzip \
    nano \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# create directories
RUN mkdir -p ${DATA_DIR} ${WWW_DIR} /var/log/supervisor /etc/ssl/ocsp /var/run/ocsp
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY init_ca.sh /init_ca.sh
COPY scripts /usr/local/bin/scripts
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY openssl/openssl-root.cnf /etc/ssl/openssl-root.cnf
COPY openssl/openssl-inter.cnf /etc/ssl/openssl-inter.cnf
COPY php/index.php ${WWW_DIR}/index.php
RUN chmod +x /entrypoint.sh /init_ca.sh /usr/local/bin/scripts/*.sh

# make www available, set permissions
RUN chown -R www-data:www-data ${WWW_DIR} ${DATA_DIR}
EXPOSE 443 80 2560 8080

CMD ["/entrypoint.sh"]
