#!/usr/bin/env bash
# Скрипт для логирования
# Подключается в других скриптах через source log.sh

set -Eeuo pipefail

# Путь к файлу лога
# По умолчанию: logs/script.log в текущем рабочем каталоге
# Можно переопределить перед подключением скрипта
: "${LOG_PATH:=$(pwd)/logs/script.log}"

# Создаём директорию для логов, если её нет
mkdir -p "$(dirname "${LOG_PATH}")"

# Цвета для вывода в терминал (если поддерживается)
if [[ -t 1 ]] && [[ -t 2 ]]; then
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_RED="\033[31m"
    readonly COLOR_GREEN="\033[32m"
    readonly COLOR_YELLOW="\033[33m"
    readonly COLOR_BLUE="\033[34m"
else
    readonly COLOR_RESET=""
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_BLUE=""
fi

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
