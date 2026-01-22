#!/usr/bin/env bash

# Путь к текущему каталогу скрипта (для относительных путей)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Подключаем функции логирования
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

# Имя, которое будет использовано в записях лога
RESTIC_FORGET_LOGNAME="RESTIC_FORGET"

restic_forget() {
    log_info "[$RESTIC_FORGET_LOGNAME] Создание каталога кэша"
    sudo mkdir -p "${RESTIC_CACHE_DIR}" || {
        log_error "[$RESTIC_FORGET_LOGNAME] Не удалось создать каталог кэша ${RESTIC_CACHE_DIR}"
        exit 1
    }

    # Экспортируем пароль, иначе restic будет пытаться запросить его в терминале
    export RESTIC_PASSWORD

    # Формируем команду `restic forget`
    CMD="systemd-run --scope -p CPUQuota=100% -p MemoryLimit=1G -- restic -r "${RESTIC_REPO}" forget --keep-daily 14 --keep-weekly 4 --keep-monthly 4 --keep-yearly 2 --prune --cache-dir "${RESTIC_CACHE_DIR}""

    log_info "[$RESTIC_FORGET_LOGNAME] Запускаю удаление старых снимков: $CMD"
    eval $CMD &>> $LOG_PATH || {
            log_error "[$RESTIC_FORGET_LOGNAME] Ошибка при удалении старых снимков"
            return 1
        }

        log_success "[$RESTIC_FORGET_LOGNAME] Удаление старых снимков завершено успешно"
        return 0
}