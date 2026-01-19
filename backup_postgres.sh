#!/usr/bin/env bash
set -Eeuo pipefail

# Загрузка библиотек логирования и healthcheck
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }
source "${SCRIPT_DIR}/hc.sh" || { echo "Failed to load hc.sh"; exit 1; }

# Конфигурация
HC_NAME="navigator"
HC_SLUG="${HC_NAME}-db-postgres"
PG_USER="postgres"
PG_BIN="/usr/bin/pg_dump"
PG_BIN_ALL="/usr/bin/pg_dumpall"
BACKUP_DIR="/bak/db"

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

# Начало healthcheck
check_start "${HC_SLUG}"

# Создание директории для бекапов
log_info "Создание директории для бекапов: ${BACKUP_DIR}"
sudo mkdir -p "${BACKUP_DIR}" || {
    log_error "Не удалось создать директорию ${BACKUP_DIR}"
    check_fail "${HC_SLUG}"
    exit 1
}
sudo chown "${PG_USER}:${PG_USER}" "${BACKUP_DIR}" 2>/dev/null || true

# Определение имени файла бекапа
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [[ "${TARGET}" == "alldb" ]]; then
    BACKUP_FILE="${BACKUP_DIR}/dump_alldb_${TIMESTAMP}.tar.gz"
    log_info "Начинаю бекап всех баз данных в ${BACKUP_FILE}"
    
    # Выполнение pg_dumpall
    if sudo -u "${PG_USER}" "${PG_BIN_ALL}" | gzip > "${BACKUP_FILE}"; then
        log_success "Бекап всех баз успешно создан"
        check_success "${HC_SLUG}"
    else
        log_error "Ошибка при создании бекапа всех баз"
        check_fail "${HC_SLUG}"
        exit 1
    fi
else
    # Бекап конкретной базы данных
    DB_NAME="${TARGET}"
    BACKUP_FILE="${BACKUP_DIR}/dump_${DB_NAME}_${TIMESTAMP}.tar.gz"
    log_info "Начинаю бекап базы данных '${DB_NAME}' в ${BACKUP_FILE}"
    
    # Проверка существования базы данных (опционально)
    # Выполнение pg_dump
    if sudo -u "${PG_USER}" "${PG_BIN}" "${DB_NAME}" | gzip > "${BACKUP_FILE}"; then
        log_success "Бекап базы '${DB_NAME}' успешно создан"
        check_success "${HC_SLUG}"
    else
        log_error "Ошибка при создании бекапа базы '${DB_NAME}'"
        check_fail "${HC_SLUG}"
        exit 1
    fi
fi

# Проверка размера файла
if [[ -f "${BACKUP_FILE}" ]]; then
    FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    log_info "Файл бекапа создан: ${BACKUP_FILE} (размер: ${FILE_SIZE})"
else
    log_warn "Файл бекапа не найден после операции"
fi

exit 0
