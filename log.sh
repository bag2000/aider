#!/usr/bin/env bash
# Скрипт для логирования
# Подключается в других скриптах через source log.sh

set -Eeuo pipefail

# Путь к файлу лога
# По умолчанию: logs/script.log в текущем рабочем каталоге
# Можно переопределить перед подключением скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${LOG_PATH:=$SCRIPT_DIR/logs/script.log}"

# Создаём директорию для логов, если её нет
mkdir -p "$(dirname "${LOG_PATH}")"

# # Цвета для вывода в терминал
COLOR_RESET="\033[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"

# Функция для записи в файл лога
_log_to_file() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $*" >> "${LOG_PATH}"
}

# Информационное сообщение
log_info() {
    local msg="$*"
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} ${msg}"
    _log_to_file "[INFO] ${msg}"
}

# Сообщение об успехе
log_success() {
    local msg="$*"
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} ${msg}"
    _log_to_file "[SUCCESS] ${msg}"
}

# Сообщение об ошибке
log_error() {
    local msg="$*"
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} ${msg}" >&2
    _log_to_file "[ERROR] ${msg}"
}

# Предупреждение
log_warn() {
    local msg="$*"
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} ${msg}" >&2
    _log_to_file "[WARN] ${msg}"
}

# Экспортируем функции для использования в других скриптах
export -f log_info log_success log_error log_warn _log_to_file
export LOG_PATH
