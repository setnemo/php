# Nginx + php-fpm (v8) + nodejs

Based on php:php:8.2.12-fpm-alpine3.18

## PHP Modules

In this image it contains following PHP modules:

```
# php -m
[PHP Modules]
bcmath
Core
ctype
curl
date
dom
fileinfo
filter
ftp
gd
hash
iconv
igbinary
imap
intl
json
libxml
mbstring
memcached
msgpack
mysqli
mysqlnd
openssl
pcre
PDO
pdo_mysql
pdo_pgsql
pdo_sqlite
pgsql
Phar
posix
random
readline
redis
Reflection
session
SimpleXML
soap
sockets
sodium
SPL
sqlite3
standard
tokenizer
xdebug
xml
xmlreader
xmlwriter
Zend OPcache
zip
zlib

[Zend Modules]
Xdebug
Zend OPcache
```

## How to use

For example, use this docker image to deploy a **Laravel 10** project.

## Environment
```dotenv
COMPOSERMIRROR=packagist.pages.dev
TZ=Europe/Kyiv
ERRORS=1
PHP_ERRORS_STDERR=1
PHP_MEM_LIMIT=1024
PHP_POST_MAX_SIZE=1024
PHP_UPLOAD_MAX_FILESIZE=1024
PHP_REDIS_SESSION_HOST=sessionredis
ENABLE_XDEBUG=1
RUN_SCRIPTS #/var/www/html/scripts/
CREATE_LARAVEL_STORAGE=1
```

For example, use this docker image to deploy a **Laravel 10** project.

## Develop with this image

Another example to develop with this image for a **Laravel 9** project, you may modify the `docker-compose.yml` of your project.

Make sure you have correct environment parameters set:

```yaml
# For more information: https://laravel.com/docs/sail
version: '3'
services:
  nginx:
    image: ghcr.io/setnemo/nginx:latest
    environment:
      WEBROOT: '/var/www/html/public'
      CREATE_LARAVEL_STORAGE: '1'
      PHPFPMHOST: 'laravel'
    ports:
      - '${APP_PORT:-80}:80'
    volumes:
      - '.:/var/www/html'
    networks:
      - sail
    depends_on:
      - laravel
  laravel:
    image: ghcr.io/setnemo/php:latest
    environment:
      PHP_UPLOAD_MAX_FILESIZE: 1024
      PHP_REDIS_SESSION_HOST: redis
      CREATE_LARAVEL_STORAGE: 1
      PHP_POST_MAX_SIZE: 1024
      PHP_ERRORS_STDERR: 1
      COMPOSERMIRROR: packagist.pages.dev
      PHP_MEM_LIMIT: 1024
      ENABLE_XDEBUG: 1
      WEBROOT: /var/www/html/public
      ERRORS: 1
      TZ: Europe/Kyiv
    volumes:
      - '.:/var/www/html'
      - './supervisor/deploy.conf:/etc/supervisor/conf.d/deploy.conf:ro'
      - './supervisor/schedule.conf:/etc/supervisor/conf.d/schedule.conf:ro'
    networks:
      - sail
    depends_on:
      - postgres
      - redis
  node:
    image: ghcr.io/setnemo/node:latest
    working_dir: /var/www/html
    tty: true
    ports:
      - '${VITE_PORT:-5173}:5173'
    volumes:
      - ./:/var/www/html
      - './supervisor/deploy.node.conf:/etc/supervisor/conf.d/deploy.node.conf:ro'
  postgres:
    image: postgres:9.5-alpine
    volumes:
      - "sail-postgres:/var/lib/postgresql/data"
    environment:
      - POSTGRES_USER=${DB_USERNAME}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=${DB_DATABASE}
    ports:
      - "${DB_PORT:-5432}:5432"
    networks:
      - sail
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 10s
      timeout: 5s
      retries: 5
  redis:
    image: 'redis:alpine'
    ports:
      - '${REDIS_PORT:-6379}:6379'
    volumes:
      - 'sail-redis:/data'
    networks:
      - sail
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      retries: 3
      timeout: 5s
networks:
  sail:
    driver: bridge
volumes:
  sail-postgres:
    driver: local
  sail-redis:
    driver: local
```
