#!/usr/bin/env bash
# Heartbeat скрипт для отправки уведомлений в Healthchecks.io
# Использование:
#   ./hc.sh check_success SLUG
#   source ./hc.sh && check_success SLUG

set -Eeuo pipefail

# Подключаем логирование, если файл существует
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/log.sh" ]]; then
    # shellcheck source=./log.sh
    source "$(dirname "${BASH_SOURCE[0]}")/log.sh"
elif [[ -f "/linux/log.sh" ]]; then
    # альтернативный путь
    # shellcheck source=/linux/log.sh
    source "/linux/log.sh"
else
    # Фолбэк функции, если log.sh не найден
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
fi

# Базовый URL сервиса Healthchecks
: "${BASE_URL:="https://hc.t8.ru/ping"}"
# API ключ (ping API) - должен быть задан явно
: "${PING_API:=}"

# Проверяем, что PING_API не пустой
if [[ -z "${PING_API}" ]]; then
    # Используем log_error, если log.sh подключен, иначе echo
    if command -v log_error >/dev/null 2>&1; then
        log_error "Переменная PING_API не задана. Задайте её перед использованием скрипта."
    else
        echo "[ERROR] Переменная PING_API не задана. Задайте её перед использованием скрипта." >&2
    fi
    exit 1
fi

# Функция отправки heartbeat
_send_hc() {
    local slug="$1"
    local action="${2:-}"  # success, fail, start или пусто для обычного ping
    local url="${BASE_URL}/${PING_API}/${slug}"
    
    if [[ -n "${action}" ]]; then
        url="${url}/${action}"
    fi
    
    log_info "Отправка healthcheck: ${url}"
    
    # Используем curl с таймаутом
    if curl -fsS --max-time 10 -X GET "${url}" > /dev/null 2>&1; then
        log_success "Heartbeat отправлен успешно (${slug}${action:+/${action}})"
        return 0
    else
        log_error "Не удалось отправить heartbeat (${slug}${action:+/${action}})"
        return 1
    fi
}

# Успешное выполнение
check_success() {
    local slug="$1"
    _send_hc "${slug}" ""          # обычный ping для успеха
}

# Начало выполнения
check_start() {
    local slug="$1"
    _send_hc "${slug}" "start"
}

# Ошибка выполнения
check_fail() {
    local slug="$1"
    _send_hc "${slug}" "fail"
}

# Если скрипт запущен напрямую (не через source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Использование: $0 {check_success|check_start|check_fail} SLUG" >&2
        echo "Пример: $0 check_success navigator-db-backup-postgres-1" >&2
        exit 1
    fi
    
    action="$1"
    slug="$2"
    
    case "${action}" in
        check_success)
            check_success "${slug}"
            ;;
        check_start)
            check_start "${slug}"
            ;;
        check_fail)
            check_fail "${slug}"
            ;;
        *)
            log_error "Неизвестное действие: ${action}"
            echo "Допустимые действия: check_success, check_start, check_fail" >&2
            exit 1
            ;;
    esac
fi
