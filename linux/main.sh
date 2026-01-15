#!/bin/bash

# Подключаем скрипты
source ./log.sh &> /dev/null
source ./hc.sh &> /dev/null


FULL_URL="${HEALTHCHECK_BASE_URL}/ping/${HEALTHCHECK_API_PING}/navigator-db-backup-postgres-1"
echo $FULL_URL
check_start "$FULL_URL"