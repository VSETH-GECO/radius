#!/bin/bash

set -eo pipefail

echo "--------------------------------"

echo "Bootstrapping at $(date) on $(hostname -f)"

echo "--------------------------------"
echo "DB config"
echo "Host: ${RADIUS_DB_HOST}"
echo "Port: ${RADIUS_DB_PORT}"
echo "User: ${RADIUS_DB_USER}"
echo "Database: ${RADIUS_DB_DB}"
# RADIUS_DB_PASSWORD is not printed

echo "--------- Static config -------------"
# these scripts are added by the k8s deployment
# https://github.com/VSETH-GECO/k8s/blob/main/radius/configmap.yaml
ls -la /config
bash /config/clients.sh

echo "Handing over to FreeRADIUS"
exec bash -x /docker-entrypoint.sh "$@"
