#!/bin/bash

set -e
set -o pipefail

# Определяем базовый каталог
BASE_DIR=$(dirname "$(readlink -f "$0")")

# Подключаем конфигурацию и модули
source "${BASE_DIR}/init.conf"

# Формируем абсолютные пути сразу после загрузки конфигурации
export ABS_RESTIC_PASSWORD_FILE="${BASE_DIR}/${RESTIC_PASSWORD_FILE}"
export ABS_RESTIC_CACHE_DIR="${BASE_DIR}/${RESTIC_CACHE_DIR}"
export ABS_EXCLUDE_FILE="${BASE_DIR}/${EXCLUDE_FILE}"
export ABS_LOG_FILE="${BASE_DIR}/${LOG_FILE}"

# Экспортируем переменные для restic
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY}"
export RESTIC_PASSWORD_FILE="${ABS_RESTIC_PASSWORD_FILE}"
export RESTIC_CACHE_DIR="${ABS_RESTIC_CACHE_DIR}"

# Создаем папку для кеша, если её нет
mkdir -p "$RESTIC_CACHE_DIR"

# Подключаем модули после определения переменных
source "${BASE_DIR}/restic_backup.sh"
source "${BASE_DIR}/restic_forget.sh"

# Общая функция логирования
log() {
    local message="$1"
    local log_file="${ABS_LOG_FILE}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" | tee -a "$log_file"
}

# Проверка на запуск от root
if [[ $EUID -ne 0 ]]; then
    log "ОШИБКА: Этот скрипт должен быть запущен с правами root."
    exit 1
fi

# Главная функция
main() {
    log "Запуск системы бэкапа"
    
    # Запуск бэкапа
    run_restic_backup
    
    # Запуск очистки старых снимков
    run_restic_forget
    
    log "Все операции завершены успешно"
}

# Вызов главной функции
main "$@"
