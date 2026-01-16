#!/usr/bin/env bash
# Healthcheck скрипт
# Можно запускать напрямую: ./hc.sh start <slug>
# Или подключать в других скриптах: source hc.sh

set -Eeuo pipefail

# Подключаем скрипт логирования
# Предполагается, что log.sh находится в той же директории
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh"

# Базовые переменные
# Можно переопределить перед вызовом функций
: "${BASE_URL:=http://localhost}"
: "${PING_API:=/api/health}"
: "${HC_METHOD:=GET}"
: "${HC_METHOD:=GET}"

# Вспомогательная функция для отправки ping в Healthchecks.io
_send_ping() {
    local suffix="${1:-}"
    # Формируем URL: BASE_URL/PING_API[/suffix]
    local ping_url="${BASE_URL%/}/${PING_API#/}"
    if [[ -n "${suffix}" ]]; then
        ping_url="${ping_url}/${suffix}"
    fi
    
    log_info "Отправляем ping на ${ping_url}"
    
    # Пробуем отправить запрос с выводом отладочной информации
    if command -v curl &> /dev/null; then
        # Используем -v для verbose, но перенаправляем stderr во временный файл
        local temp_file
        temp_file=$(mktemp)
        local http_code
        # Отправляем запрос с выбранным методом и сохраняем HTTP код
        local curl_opts=()
        if [[ "${HC_METHOD}" == "POST" ]]; then
            curl_opts=(-X POST)
        fi
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "${curl_opts[@]}" --max-time 10 "${ping_url}" 2>"${temp_file}")
        local curl_exit=$?
        
        if [[ ${curl_exit} -eq 0 ]]; then
            log_info "HTTP код ответа: ${http_code}"
            if [[ "${http_code}" =~ ^(2|3)[0-9][0-9]$ ]]; then
                rm -f "${temp_file}"
                return 0
            else
                log_error "Сервер вернул код ошибки: ${http_code}"
                # Выводим отладочную информацию
                if [[ -s "${temp_file}" ]]; then
                    log_error "Детали curl: $(cat "${temp_file}")"
                fi
                rm -f "${temp_file}"
                return 1
            fi
        else
            log_error "Curl завершился с кодом ${curl_exit}"
            if [[ -s "${temp_file}" ]]; then
                log_error "Детали curl: $(cat "${temp_file}")"
            fi
            rm -f "${temp_file}"
            return 1
        fi
    elif command -v wget &> /dev/null; then
        # Для wget
        local wget_output
        wget_output=$(wget --timeout=10 --tries=1 -O /dev/null "${ping_url}" 2>&1)
        local wget_exit=$?
        if [[ ${wget_exit} -eq 0 ]]; then
            return 0
        else
            log_error "Wget завершился с кодом ${wget_exit}"
            log_error "Детали wget: ${wget_output}"
            return 1
        fi
    else
        log_error "Не найдены curl или wget для отправки ping"
        return 2
    fi
}

# Функция для начала проверки
check_start() {
    local slug="$1"
    log_info "Начинаем проверку: ${slug}"
    # Отправляем стартовый ping
    if _send_ping "start"; then
        log_info "Стартовый ping отправлен успешно"
    else
        log_error "Не удалось отправить стартовый ping"
    fi
    echo "Проверка ${slug} запущена"
}

# Функция для успешного завершения проверки
check_success() {
    local slug="$1"
    log_success "Проверка успешно завершена: ${slug}"
    # Отправляем успешный ping
    if _send_ping; then
        log_info "Успешный ping отправлен"
    else
        log_error "Не удалось отправить успешный ping"
    fi
    echo "Проверка ${slug} прошла успешно"
}

# Функция для неудачного завершения проверки
check_fail() {
    local slug="$1"
    local reason="${2:-Неизвестная ошибка}"
    log_error "Проверка завершилась неудачей: ${slug} - ${reason}"
    # Отправляем ping о неудаче
    if _send_ping "fail"; then
        log_info "Ping о неудаче отправлен"
    else
        log_error "Не удалось отправить ping о неудаче"
    fi
    echo "Проверка ${slug} не удалась: ${reason}"
    exit 1
}

# Функция для выполнения проверки здоровья
perform_healthcheck() {
    local slug="$1"
    check_start "${slug}"
    
    # Формируем URL для проверки
    # Удаляем конечный слеш из BASE_URL и начальный слеш из PING_API
    local health_url="${BASE_URL%/}/${PING_API#/}"
    
    log_info "Выполняем запрос к ${health_url}"
    
    # Выполняем HTTP-запрос
    if command -v curl &> /dev/null; then
        if curl -s -f --max-time 10 "${health_url}" > /dev/null; then
            check_success "${slug}"
        else
            check_fail "${slug}" "HTTP запрос не удался"
        fi
    elif command -v wget &> /dev/null; then
        if wget -q --timeout=10 --tries=1 -O /dev/null "${health_url}" 2>/dev/null; then
            check_success "${slug}"
        else
            check_fail "${slug}" "HTTP запрос не удался"
        fi
    else
        check_fail "${slug}" "Не найдены curl или wget для выполнения HTTP запроса"
    fi
}

# Обработка аргументов командной строки
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Скрипт запущен напрямую, а не через source
    case "${1:-}" in
        start)
            if [[ -z "${2:-}" ]]; then
                log_error "Не указан slug для проверки"
                echo "Использование: $0 start <slug>"
                exit 1
            fi
            perform_healthcheck "$2"
            ;;
        -h|--help)
            echo "Использование:"
            echo "  $0 start <slug>    - запустить проверку здоровья"
            echo "  source hc.sh       - подключить функции в другой скрипт"
            echo ""
            echo "Переменные окружения:"
            echo "  BASE_URL  - базовый URL (по умолчанию: http://localhost)"
            echo "  PING_API  - путь API для проверки (по умолчанию: /api/health)"
            ;;
        *)
            log_error "Неизвестная команда: ${1:-}"
            echo "Использование: $0 start <slug>"
            echo "Используйте $0 --help для справки"
            exit 1
            ;;
    esac
fi

# Экспортируем функции для использования в других скриптах
export -f check_start check_success check_fail perform_healthcheck _send_ping
export BASE_URL PING_API HC_METHOD
