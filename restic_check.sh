#!/bin/bash

# Определяем директорию скрипта (для относительных путей)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загружаем конфигурацию и функции логирования
source "${SCRIPT_DIR}/.env" || { echo "Failed to load .env"; exit 1; }
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

restic_check() {
    log_info "[$RESTIC_CHECK_LOGNAME] Создание директории для кэша: ${RESTIC_CACHE_DIR}"
    sudo mkdir -p "${RESTIC_CACHE_DIR}" || {
        log_error "[$RESTIC_CHECK_LOGNAME] Не удалось создать директорию ${RESTIC_CACHE_DIR}"
        return 1
    }

    day=$(date +%d)

    if [ "$day" -le 28 ]; then
        log_info "[$RESTIC_CHECK_LOGNAME] Начинаю проверку репозитория $RESTIC_REPO"

        # Экспортируем пароль, иначе restic будет пытаться запросить его в терминале
        export RESTIC_PASSWORD

        CMD="systemd-run --scope -p CPUQuota=100% -p MemoryLimit=1G -- restic check --read-data-subset $day/28 -o rest.connections=20 -r $RESTIC_REPO --cache-dir $RESTIC_CACHE_DIR"

        log_info "[$RESTIC_CHECK_LOGNAME] Запускаю команду $CMD"
        eval $CMD &>> $LOG_PATH || {
            log_error "Ошибка при проверке репозитория $RESTIC_REPO"
            return 1
        }
    else
        log_info "[$RESTIC_CHECK_LOGNAME] Текущее число $day больше 28. Пропускаю проверку. Слудующая проверка 1 числа."
        return 0
    fi

    log_info "[$RESTIC_CHECK_LOGNAME] Проверка репозитория $RESTIC_REPO завершена"
    return 0
}
