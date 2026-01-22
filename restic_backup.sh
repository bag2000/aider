#!/bin/bash

# Определяем директорию скрипта (для относительных путей)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Подключаем общие функции логирования
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

restic_backup() {
    # Создаём директорию кэша (аналогично restic_check.sh) [1]
    log_info "[$RESTIC_BACKUP_LOGNAME] Создание директории кэша: ${RESTIC_CACHE_DIR}"
    sudo mkdir -p "${RESTIC_CACHE_DIR}" || {
        log_error "[$RESTIC_BACKUP_LOGNAME] Не удалось создать директорию ${RESTIC_CACHE_DIR}"
        return 1
    }

    # Формируем команду backup с ограничением ресурсов
    CMD="systemd-run --scope -p CPUQuota=100% -p MemoryLimit=1G -- restic backup ${BACKUP_PATHS} -r ${RESTIC_REPO} --cache-dir ${RESTIC_CACHE_DIR} --pack-size 128 --exclude-caches -x --tag="$(hostname)" --tag="root""
    
    log_info "[$RESTIC_BACKUP_LOGNAME] Запускаю резервное копирование: $CMD"
    eval $CMD &>> "$LOG_PATH" || {
        log_error "[$RESTIC_BACKUP_LOGNAME] Ошибка при резервном копировании"
        return 1
    }

    log_success "[$RESTIC_BACKUP_LOGNAME] Резервное копирование завершено успешно"
    return 0
}

# ---------------------- MAIN ----------------------
log_info "[$RESTIC_BACKUP_LOGNAME] Старт скрипта backup_restic.sh"

restic_backup
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    log_error "[$RESTIC_BACKUP_LOGNAME] Скрипт завершён с ошибкой (code=${EXIT_CODE})"
else
    log_info "[$RESTIC_BACKUP_LOGNAME] Скрипт завершён успешно"
fi

exit $EXIT_CODE