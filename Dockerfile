FROM node:18.1.0-alpine3.15 AS nodejs
FROM php:8.3.1-fpm-alpine3.18
USER root
ENV TZ=Etc/GMT+2
ENV OPCACHE=""
ENV COMPOSERMIRROR=""
ENV PHP_MODULE_DEPS zlib-dev libmemcached-dev cyrus-sasl-dev libpng-dev libxml2-dev krb5-dev curl-dev icu-dev \
    libzip-dev openldap-dev imap-dev postgresql-dev imagemagick imagemagick-dev
ENV fpm_conf /usr/local/etc/php-fpm.d/www.conf
ENV php_vars /usr/local/etc/php/conf.d/docker-vars.ini
COPY --from=nodejs /opt /opt
COPY --from=nodejs /usr/local /usr/local
RUN echo "cgi.fix_pathinfo=0" > ${php_vars} &&\
    echo "upload_max_filesize = 100M"  >> ${php_vars} &&\
    echo "post_max_size = 100M"  >> ${php_vars} &&\
    echo "variables_order = \"EGPCS\""  >> ${php_vars} && \
    echo "memory_limit = 1024M"  >> ${php_vars} && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 5/pm.max_children = 64/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 8/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 8/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 32/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 800/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        ${fpm_conf} \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
RUN apk add --no-cache linux-headers libstdc++ mysql-client bash bash-completion shadow \
    supervisor git zip unzip python3 coreutils libpng libmemcached-libs krb5-libs icu-libs \
    icu c-client libzip openldap-clients imap postgresql-client postgresql-libs libcap tzdata sqlite \
    lua-resty-core libc-dev make gcc clang vim bat
RUN apk add php83-pecl-imagick --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
RUN curl http://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN set -xe
RUN apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS
RUN apk add --no-cache --update --virtual .all-deps $PHP_MODULE_DEPS
RUN git clone https://github.com/Imagick/imagick --depth 1 /tmp/imagick && \
    cd /tmp/imagick && phpize && ./configure && make && make install
RUN docker-php-ext-enable imagick
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions sockets \
    && install-php-extensions bcmath
RUN docker-php-ext-install pgsql pdo_pgsql zip imap dom mysqli pdo pdo_mysql pgsql gd intl soap exif
RUN if [[ "$OPCACHE" != "0" ]]; then docker-php-ext-install opcache; fi
RUN printf "\n\n\n\n" | pecl install -o -f redis
RUN rm -rf /tmp/pear
RUN docker-php-ext-enable redis
RUN docker-php-ext-enable sockets
RUN pecl install msgpack && docker-php-ext-enable msgpack
RUN pecl install igbinary && docker-php-ext-enable igbinary
RUN printf "\n\n\n\n\n\n\n\n\n\n" | pecl install memcached
RUN docker-php-ext-enable memcached
COPY conf/supervisord.conf /etc/supervisord.conf
RUN apk del .all-deps .phpize-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
    && set -ex \
    && mkdir -p /var/log/supervisor
RUN if [[ "$COMPOSERMIRROR" != "" ]]; then composer config -g repos.packagist composer ${COMPOSERMIRROR}; fi
RUN echo "date.timezone="${TZ} > /usr/local/etc/php/conf.d/timezone.ini \
    && rm -f /etc/localtime \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && echo "log_errors = On" >> /usr/local/etc/php/conf.d/docker-vars.ini  \
    && echo "error_log = /dev/stderr" >> /usr/local/etc/php/conf.d/docker-vars.ini  \
    && sed -i "s/memory_limit = 128M/memory_limit = 1024M/g" /usr/local/etc/php/conf.d/docker-vars.ini \
    && sed -i "s/post_max_size = 100M/post_max_size = 1024M/g" /usr/local/etc/php/conf.d/docker-vars.ini \
    && sed -i "s/upload_max_filesize = 100M/upload_max_filesize = 1024M/g" /usr/local/etc/php/conf.d/docker-vars.ini \
    && mkdir -p /var/www/html/storage/{logs,app/public,framework/{cache/data,sessions,testing,views}}
RUN echo '* * * * * /bin/bash -c "if [ -f \"/dev/shm/supervisor.sock\" ] ; then echo skipping; else /usr/bin/supervisord -c /etc/supervisord.conf; fi;"' >> crontab.txt
RUN echo '* * * * * /bin/bash -c "if [ -f \"/var/www/html/supervisor-restart.pid\" ] ; then supervisorctl restart all && rm /var/www/html/supervisor-restart.pid; else sleep 45; fi;"' >> crontab.txt
RUN /usr/bin/crontab ./crontab.txt
RUN bash -c "/usr/sbin/crond -b" &
WORKDIR "/var/www/html"
STOPSIGNAL SIGQUIT
EXPOSE 9000
CMD ["php-fpm"]