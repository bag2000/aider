#!/usr/bin/env bash
source ./.env

# Healthchecks скрипт для отправки уведомлений в Healthchecks.io
# Использование:
#   ./hc.sh check_success SLUG ["ТЕКСТ СООБЩЕНИЯ"]
#   source ./hc.sh && check_success SLUG ["ТЕКСТ СООБЩЕНИЯ"]

set -Eeuo pipefail

# Подключаем логирование, если файл существует
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/log.sh" ]]; then
    # shellcheck source=./log.sh
    source "$(dirname "${BASH_SOURCE[0]}")/log.sh"
else
    # Фолбэк функции, если log.sh не найден
    echo "log.sh не найден"
    exit 1
fi

# Базовый URL сервиса Healthchecks (обязательный)
: "${HC_BASE_URL:=}"
# API ключ (ping API) - обязательный
: "${HC_PING_API:=}"
# DNS override для curl (например, "192.168.1.1:443:hc.exam.ru")
: "${HC_DNS:=}"

# Проверяем, что HC_BASE_URL не пустой
if [[ -z "${HC_BASE_URL}" ]]; then
    if command -v log_error >/dev/null 2>&1; then
        log_error "[$HC_LOGNAME] Переменная HC_BASE_URL не задана. Задайте её перед использованием скрипта."
    else
        echo "[ERROR] Переменная HC_BASE_URL не задана. Задайте её перед использованием скрипта." >&2
    fi
    exit 1
fi

# Проверяем, что HC_PING_API не пустой
if [[ -z "${HC_PING_API}" ]]; then
    # Используем log_error, если log.sh подключен, иначе echo
    if command -v log_error >/dev/null 2>&1; then
        log_error "[$HC_LOGNAME] Переменная HC_PING_API не задана. Задайте её перед использованием скрипта."
    else
        echo "[ERROR] Переменная HC_PING_API не задана. Задайте её перед использованием скрипта." >&2
    fi
    exit 1
fi

# Функция отправки Healthchecks
_send_hc() {
    local slug="$1"
    local action="${2:-}"  # success, fail, start или пусто для обычного ping
    local message="${3:-}" # необязательное текстовое сообщение
    local url="${HC_BASE_URL}/${HC_PING_API}/${slug}"
    
    if [[ -n "${action}" ]]; then
        url="${url}/${action}"
    fi
    
    log_info "[$HC_LOGNAME] Отправка healthcheck: ${url}"
    
    # Подготавливаем аргументы curl
    local curl_args=()
    curl_args+=(-fsS)
    curl_args+=(--max-time 10)
    
    # Добавляем --resolve, если HC_DNS задан
    if [[ -n "${HC_DNS}" ]]; then
        curl_args+=(--resolve "${HC_DNS}")
    fi
    
    # Если есть сообщение, отправляем POST с телом, иначе GET
    if [[ -n "${message}" ]]; then
        curl_args+=(-X POST)
        curl_args+=(--data-raw "${message}")
        log_info "[$HC_LOGNAME] С текстом: ${message}"
    else
        curl_args+=(-X GET)
    fi
    
    curl_args+=("${url}")
    
    # Используем curl с таймаутом
    if curl "${curl_args[@]}" > /dev/null 2>&1; then
        log_success "[$HC_LOGNAME] Healthchecks отправлен успешно (${slug}${action:+/${action}})"
        return 0
    else
        log_error "[$HC_LOGNAME] Не удалось отправить Healthchecks (${slug}${action:+/${action}})"
        return 1
    fi
}

# Успешное выполнение
check_success() {
    local slug="$1"
    local message="${2:-}"
    _send_hc "${slug}" "" "${message}"          # обычный ping для успеха
}

# Начало выполнения
check_start() {
    local slug="$1"
    local message="${2:-}"
    _send_hc "${slug}" "start" "${message}"
}

# Ошибка выполнения
check_fail() {
    local slug="$1"
    local message="${2:-}"
    _send_hc "${slug}" "fail" "${message}"
}

# Если скрипт запущен напрямую (не через source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Использование: $0 {check_success|check_start|check_fail} SLUG [\"ТЕКСТ СООБЩЕНИЯ\"]" >&2
        echo "Пример: $0 check_success navigator-db-backup-postgres-1" >&2
        echo "Пример с текстом: $0 check_success navigator-db-backup-postgres-1 \"Резервное копирование завершено успешно\"" >&2
        exit 1
    fi
    
    action="$1"
    slug="$2"
    message="${3:-}"
    
    case "${action}" in
        check_success)
            check_success "${slug}" "${message}"
            ;;
        check_start)
            check_start "${slug}" "${message}"
            ;;
        check_fail)
            check_fail "${slug}" "${message}"
            ;;
        *)
            log_error "[$HC_LOGNAME] Неизвестное действие: ${action}"
            echo "Допустимые действия: check_success, check_start, check_fail" >&2
            exit 1
            ;;
    esac
fi
