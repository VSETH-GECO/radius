#!/bin/bash

set -eo pipefail

echo "--------------------------------"

echo "Boostrapping at $(date) on $(hostname -f)"

echo "--------------------------------"
echo "DB config"
echo "Host: ${RADIUS_DB_HOST}"
echo "Port: ${RADIUS_DB_PORT}"
echo "User: ${RADIUS_DB_USER}"
echo "Database: ${RADIUS_DB_DB}"
# RADIUS_DB_PASSWORD is not printed
envsubst '$RADIUS_DB_HOST,$RADIUS_DB_PORT,$RADIUS_DB_USER,$RADIUS_DB_DB,$RADIUS_DB_PASSWORD' < /etc/freeradius/mods-available/sql.env > /etc/freeradius/mods-available/sql


echo "--------- Static config -------------"
ls -la /config
bash /config/clients.sh

echo "Handing over to FreeRADIUS"
exec bash -x /docker-entrypoint.sh "$@"