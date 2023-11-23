FROM php:8.2.12-fpm-alpine3.18
USER root
ENV TZ=Etc/GMT
ENV COMPOSERMIRROR=""
ENV PHP_MODULE_DEPS zlib-dev libmemcached-dev cyrus-sasl-dev libpng-dev libxml2-dev krb5-dev curl-dev icu-dev libzip-dev openldap-dev imap-dev postgresql-dev
ENV fpm_conf /usr/local/etc/php-fpm.d/www.conf
ENV php_vars /usr/local/etc/php/conf.d/docker-vars.ini
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
RUN curl http://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
RUN apk add --no-cache php8-cli php8-dev linux-headers php82-bcmath libstdc++ mysql-client bash bash-completion shadow \
        supervisor git zip unzip python2 coreutils libpng libmemcached-libs krb5-libs icu-libs \
        icu c-client libzip openldap-clients imap postgresql-client postgresql-libs libcap tzdata sqlite \
        lua-resty-core nginx-mod-http-lua libc-dev make gcc clang vim bat \
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN set -xe
RUN apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS
RUN apk add --no-cache --update --virtual .all-deps $PHP_MODULE_DEPS
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions sockets \
    && install-php-extensions bcmath \
    && docker-php-ext-install pgsql \
    && docker-php-ext-install pdo_pgsql \
    && docker-php-ext-install zip \
    && docker-php-ext-install imap \
    && docker-php-ext-install dom \
    && docker-php-ext-install opcache \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install pgsql \
    && docker-php-ext-install gd \
    && docker-php-ext-install intl \
    && docker-php-ext-install soap
RUN printf "\n\n\n\n" | pecl install -o -f redis
RUN rm -rf /tmp/pear
RUN docker-php-ext-enable redis
RUN docker-php-ext-enable sockets
RUN pecl install msgpack && docker-php-ext-enable msgpack
RUN pecl install igbinary && docker-php-ext-enable igbinary
RUN printf "\n\n\n\n\n\n\n\n\n\n" | pecl install memcached
RUN docker-php-ext-enable memcached
USER root
WORKDIR "/root"
COPY conf/supervisord.conf /etc/supervisord.conf
COPY start.sh /root/start.sh
RUN apk del .all-deps .phpize-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
    && apk update && apk add  --no-cache supervisor \
    && apk add --no-cache bash \
    && set -ex \
    && mkdir -p /var/log/supervisor \
    && chmod +x /root/start.sh
WORKDIR "/var/www/html"
CMD ["sh", "-c", "/root/start.sh"]
