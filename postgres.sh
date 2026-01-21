#!/bin/bash

# Определяем директорию скрипта для относительных путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загружаем конфигурацию и функции логирования
source "${SCRIPT_DIR}/.env" || { echo "Failed to load .env"; exit 1; }
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

# Создание директории для бекапов
log_info "[$BACKUP_POSTGRES_LOGNAME] Создание директории для бекапов: ${BACKUP_POSTGRES_DIR}"
sudo mkdir -p "${BACKUP_POSTGRES_DIR}" || {
    log_error "[$BACKUP_POSTGRES_LOGNAME] Не удалось создать директорию ${BACKUP_POSTGRES_DIR}"
    exit 1
}

