#!/usr/bin/env bash
set -Eeuo pipefail

# Загрузка библиотеки логирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

# Конфигурация
BACKUP_POSTGRES_USER="postgres"
BACKUP_POSTGRES_BIN="/usr/bin/pg_dump"
BACKUP_POSTGRES_BIN_ALL="/usr/bin/pg_dumpall"
BACKUP_POSTGRES_DIR="/bak/db"

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
    log_error "Требуется ровно один параметр"
    show_help
    exit 1
fi

TARGET="$1"

# Создание директории для бекапов
log_info "Создание директории для бекапов: ${BACKUP_POSTGRES_DIR}"
sudo mkdir -p "${BACKUP_POSTGRES_DIR}" || {
    log_error "Не удалось создать директорию ${BACKUP_POSTGRES_DIR}"
    exit 1
}
sudo chown "${BACKUP_POSTGRES_USER}:${BACKUP_POSTGRES_USER}" "${BACKUP_POSTGRES_DIR}" 2>/dev/null || true

# Определение имени файла бекапа
if [[ "${TARGET}" == "alldb" ]]; then
    BACKUP_FILE="${BACKUP_POSTGRES_DIR}/dump_alldb.gz"
    log_info "Начинаю бекап всех баз данных в ${BACKUP_FILE}"
    
    # Выполнение pg_dumpall
    if sudo -u "${BACKUP_POSTGRES_USER}" "${BACKUP_POSTGRES_BIN_ALL}" | gzip > "${BACKUP_FILE}"; then
        log_success "Бекап всех баз успешно создан"
    else
        log_error "Ошибка при создании бекапа всех баз"
        exit 1
    fi
else
    # Бекап конкретной базы данных
    DB_NAME="${TARGET}"
    BACKUP_FILE="${BACKUP_POSTGRES_DIR}/dump_${DB_NAME}.gz"
    log_info "Начинаю бекап базы данных '${DB_NAME}' в ${BACKUP_FILE}"
    
    # Проверка существования базы данных (опционально)
    # Выполнение pg_dump
    if sudo -u "${BACKUP_POSTGRES_USER}" "${BACKUP_POSTGRES_BIN}" "${DB_NAME}" | gzip > "${BACKUP_FILE}"; then
        log_success "Бекап базы '${DB_NAME}' успешно создан"
    else
        log_error "Ошибка при создании бекапа базы '${DB_NAME}'"
        exit 1
    fi
fi

# Проверка целостности бекапа
log_info "Проверка целостности бекапа..."
if gunzip -c "${BACKUP_FILE}" | grep -m1 "CREATE TABLE" > /dev/null 2>&1; then
    log_success "Бекап содержит данные (найдена CREATE TABLE)"
else
    log_error "Бекап не содержит ожидаемых данных (CREATE TABLE не найдена)"
    exit 1
fi

# Проверка размера файла
if [[ -f "${BACKUP_FILE}" ]]; then
    FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    log_info "Файл бекапа создан: ${BACKUP_FILE} (размер: ${FILE_SIZE})"
else
    log_warn "Файл бекапа не найден после операции"
fi

exit 0
