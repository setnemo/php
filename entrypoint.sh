#!/bin/bash
set -m
php-fpm &
crond &
START_SCRIPT=/var/www/html/start.sh
if [ -f "$START_SCRIPT" ] ; then
    chmod +x $START_SCRIPT
    bash $START_SCRIPT
fi
fg %1