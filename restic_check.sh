#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

log_info "[$RESTIC_CHECK_LOGNAME] Создание директории для кэша: ${RESTIC_CACHE_DIR}"
sudo mkdir -p "${RESTIC_CACHE_DIR}" || {
    log_error "[$RESTIC_CHECK_LOGNAME] Не удалось создать директорию ${RESTIC_CACHE_DIR}"
    exit 1
}

day=$(date +%d)

if [ "$day" -le 28 ]; then
    log_info "Начинаю проверку репозитория $RESTIC_REPO"
    systemd-run --scope \
    -p CPUQuota=100% \
    -p MemoryLimit=1G \
    -- restic \
    -o rest.connections=20 \
    -r $RESTIC_REPO \
    --cache-dir $RESTIC_CACHE_DIR \
    check / \
    --read-data-subset $day/28 \
    &>> $LOG_PATH || {
        log_error "Ошибка при проверке репозитория $RESTIC_REPO"
        exit 1
    }
else
    log_info "Текущее число $day больше 28. Пропускаю проверку. Слудующая проверка 1 числа."
fi

log_info "Проверка репозитория $RESTIC_REPO завершена"
