#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }
source "${SCRIPT_DIR}/hc_create.sh" || { echo "Failed to load hc_create.sh"; exit 1; }
source "${SCRIPT_DIR}/hc_ping.sh" || { echo "Failed to load hc_ping.sh"; exit 1; }
source "${SCRIPT_DIR}/restic_check.sh" || { echo "Failed to load restic_check.sh"; exit 1; }
source "${SCRIPT_DIR}/restic_backup.sh" || { echo "Failed to load restic_backup.sh"; exit 1; }
source "${SCRIPT_DIR}/restic_forget.sh" || { echo "Failed to load restic_forget.sh"; exit 1; }

log_info "*************************************************************************************"
# Переменная для лога ошибок
# В конце она отправляется в чек
main_check=""

# Создаю чек
hc_create

# Начало бекапа
hc_ping_start "Начало резервного копирования"

# Создать дамп progress
# $SCRIPT_DIR/backup_postgres.sh "alldb" || main_check+="ОШИБКА postgres alldb "            # Все базы
# $SCRIPT_DIR/backup_postgres.sh "navigator" || main_check+="ОШИБКА postgres navigator "    № Конкретная база

# restic_check || main_check+="ОШИБКА restic check "
# restic_backup || main_check+="ОШИБКА restic backup "
restic_forget || main_check+="ОШИБКА restic forget "

if [ -z "$main_check" ]; then
    hc_ping_success "Резервное копирование успешно завершено"
else
    hc_ping_fail "$main_check"
fi
