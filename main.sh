#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }
source "${SCRIPT_DIR}/hc_create.sh" || { echo "Failed to load hc_create.sh"; exit 1; }
source "${SCRIPT_DIR}/hc_ping.sh" || { echo "Failed to load hc_ping.sh"; exit 1; }

main_check=""

# Создаю чек
hc_create

# Начало бекапа
hc_ping_start "Начало резервного копирования"

# Создать дамп progress
# export BACKUP_POSTGRES_LOGNAME="BACKUP_POSTGRESS"
# export BACKUP_POSTGRES_USER="postgres"
# export BACKUP_POSTGRES_DIR="/bak/db"
# $SCRIPT_DIR/backup_postgres.sh "alldb" || main_check+="ОШИБКА postgres alldb "
# $SCRIPT_DIR/backup_postgres.sh "navigator" || main_check+="ОШИБКА postgres navigator "

if [ -n $main_check ]; then
    hc_ping_success "Резервное копирование успешно завершено"
else
    hc_ping_fail "$main_check"
fi
