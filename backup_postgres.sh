#!/usr/bin/env bash
source ./.env

set -Eeuo pipefail

# Загрузка библиотеки логирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $(basename "$0") [alldb | <имя_базы>]

Параметры:
    alldb          - создать бекап всех баз данных (pg_dumpall)
    <имя_базы>     - создать бекап указанной базы данных (pg_dump)

Примеры:
    $(basename "$0") alldb
    $(basename "$0") navigator
EOF
}

# Проверка наличия параметра
if [[ $# -ne 1 ]]; then
    log_error "[$BACKUP_POSTGRES_LOGNAME] Требуется ровно один параметр"
    show_help
    exit 1
fi

TARGET="$1"

# Создание директории для бекапов
log_info "[$BACKUP_POSTGRES_LOGNAME] Создание директории для бекапов: ${BACKUP_POSTGRES_DIR}"
sudo mkdir -p "${BACKUP_POSTGRES_DIR}" || {
    log_error "[$BACKUP_POSTGRES_LOGNAME] Не удалось создать директорию ${BACKUP_POSTGRES_DIR}"
    exit 1
}

# Определение имени файла бекапа
if [[ "${TARGET}" == "alldb" ]]; then
    BACKUP_FILE="${BACKUP_POSTGRES_DIR}/dump_alldb.gz"
    log_info "[$BACKUP_POSTGRES_LOGNAME] Начинаю бекап всех баз данных в ${BACKUP_FILE}"
    
    # Выполнение pg_dumpall
    if (cd /tmp && sudo -u "${BACKUP_POSTGRES_USER}" pg_dumpall &> $LOG_PATH) | gzip > "${BACKUP_FILE}" &> $LOG_PATH; then
        log_success "[$BACKUP_POSTGRES_LOGNAME] Бекап всех баз успешно создан"
    else
        log_error "[$BACKUP_POSTGRES_LOGNAME] Ошибка при создании бекапа всех баз"
        exit 1
    fi
else
    # Бекап конкретной базы данных
    DB_NAME="${TARGET}"
    BACKUP_FILE="${BACKUP_POSTGRES_DIR}/dump_${DB_NAME}.gz"
    log_info "[$BACKUP_POSTGRES_LOGNAME] Начинаю бекап базы данных '${DB_NAME}' в ${BACKUP_FILE}"
    
    # Проверка существования базы данных (опционально)
    # Выполнение pg_dump
    if (cd /tmp && sudo -u "${BACKUP_POSTGRES_USER}" pg_dump "${DB_NAME}" &> $LOG_PATH) | gzip > "${BACKUP_FILE}" &> $LOG_PATH; then
        log_success "[$BACKUP_POSTGRES_LOGNAME] Бекап базы '${DB_NAME}' успешно создан"
    else
        log_error "[$BACKUP_POSTGRES_LOGNAME] Ошибка при создании бекапа базы '${DB_NAME}'"
        exit 1
    fi
fi

# Проверка целостности бекапа
log_info "[$BACKUP_POSTGRES_LOGNAME] Проверка целостности бекапа..."
if gunzip -c "${BACKUP_FILE}" 2>/dev/null | grep -E '^CREATE TABLE' > /dev/null 2>&1; then
    log_success "[$BACKUP_POSTGRES_LOGNAME] Бекап содержит данные (найдена CREATE TABLE)"
else
    log_error "[$BACKUP_POSTGRES_LOGNAME] Бекап не содержит ожидаемых данных (CREATE TABLE не найдена)"
    exit 1
fi

# Проверка размера файла
if [[ -f "${BACKUP_FILE}" ]]; then
    FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    log_info "[$BACKUP_POSTGRES_LOGNAME] Файл бекапа создан: ${BACKUP_FILE} (размер: ${FILE_SIZE})"
else
    log_warn "[$BACKUP_POSTGRES_LOGNAME] Файл бекапа не найден после операции"
fi

exit 0
