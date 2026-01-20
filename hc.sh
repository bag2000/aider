#!/usr/bin/env bash
source ./.env

# Healthchecks скрипт для отправки уведомлений в Healthchecks.io
# Использование:
#   ./hc.sh check_success SLUG ["ТЕКСТ СООБЩЕНИЯ"]
#   source ./hc.sh && check_success SLUG ["ТЕКСТ СООБЩЕНИЯ"]

set -Eeuo pipefail

# Загрузка библиотеки логирования
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

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
    
    # Определяем, является ли slug UUID (содержит дефисы и имеет длину 36 символов)
    # UUID формат: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    if [[ "${slug}" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]; then
        # Если slug - UUID, используем URL для ping по UUID
        # Убедимся, что HC_BASE_URL не заканчивается на /ping
        local base_url="${HC_BASE_URL%/ping}"
        local url="${base_url}/ping/${slug}"
    else
        # Иначе используем старый формат с HC_PING_API
        local url="${HC_BASE_URL}/${HC_PING_API}/${slug}"
    fi
    
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

# Отправка чека из файла .id_healthcheck
check_from_file() {
    local action="${1:-}"  # success, start, fail или пусто для обычного ping
    local message="${2:-}"
    local id_file=".id_healthcheck"
    
    if [[ ! -f "${id_file}" ]]; then
        log_error "[$HC_LOGNAME] Файл ${id_file} не найден. Сначала создайте чек с помощью hc_create.sh"
        return 1
    fi
    
    local slug
    slug=$(cat "${id_file}" 2>/dev/null | head -n1 | tr -d '[:space:]')
    
    if [[ -z "${slug}" ]]; then
        log_error "[$HC_LOGNAME] Файл ${id_file} пуст или содержит неверные данные"
        return 1
    fi
    
    case "${action}" in
        success|"")
            _send_hc "${slug}" "" "${message}"
            ;;
        start)
            _send_hc "${slug}" "start" "${message}"
            ;;
        fail)
            _send_hc "${slug}" "fail" "${message}"
            ;;
        *)
            log_error "[$HC_LOGNAME] Неизвестное действие для check_from_file: ${action}"
            return 1
            ;;
    esac
}

# Если скрипт запущен напрямую (не через source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Использование: $0 {check_success|check_start|check_fail|check_from_file} [SLUG|ACTION] [\"ТЕКСТ СООБЩЕНИЯ\"]" >&2
        echo "Примеры:" >&2
        echo "  $0 check_success navigator-db-backup-postgres-1" >&2
        echo "  $0 check_success navigator-db-backup-postgres-1 \"Резервное копирование завершено успешно\"" >&2
        echo "  $0 check_from_file success \"Задание выполнено\"" >&2
        echo "  $0 check_from_file start" >&2
        echo "  $0 check_from_file fail \"Произошла ошибка\"" >&2
        exit 1
    fi
    
    action="$1"
    
    case "${action}" in
        check_success)
            if [[ $# -lt 2 ]]; then
                echo "Использование: $0 check_success SLUG [\"ТЕКСТ СООБЩЕНИЯ\"]" >&2
                exit 1
            fi
            slug="$2"
            message="${3:-}"
            check_success "${slug}" "${message}"
            ;;
        check_start)
            if [[ $# -lt 2 ]]; then
                echo "Использование: $0 check_start SLUG [\"ТЕКСТ СООБЩЕНИЯ\"]" >&2
                exit 1
            fi
            slug="$2"
            message="${3:-}"
            check_start "${slug}" "${message}"
            ;;
        check_fail)
            if [[ $# -lt 2 ]]; then
                echo "Использование: $0 check_fail SLUG [\"ТЕКСТ СООБЩЕНИЯ\"]" >&2
                exit 1
            fi
            slug="$2"
            message="${3:-}"
            check_fail "${slug}" "${message}"
            ;;
        check_from_file)
            sub_action="${2:-success}"
            message="${3:-}"
            check_from_file "${sub_action}" "${message}"
            ;;
        *)
            log_error "[$HC_LOGNAME] Неизвестное действие: ${action}"
            echo "Допустимые действия: check_success, check_start, check_fail, check_from_file" >&2
            exit 1
            ;;
    esac
fi
