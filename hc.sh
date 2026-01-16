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

# Функция для начала проверки
check_start() {
    local slug="$1"
    log_info "Начинаем проверку: ${slug}"
    # Здесь можно добавить дополнительную логику
    echo "Проверка ${slug} запущена"
}

# Функция для успешного завершения проверки
check_success() {
    local slug="$1"
    log_success "Проверка успешно завершена: ${slug}"
    # Здесь можно добавить дополнительную логику
    echo "Проверка ${slug} прошла успешно"
}

# Функция для неудачного завершения проверки
check_fail() {
    local slug="$1"
    local reason="${2:-Неизвестная ошибка}"
    log_error "Проверка завершилась неудачей: ${slug} - ${reason}"
    # Здесь можно добавить дополнительную логику
    echo "Проверка ${slug} не удалась: ${reason}"
    exit 1
}

# Функция для выполнения проверки здоровья
perform_healthcheck() {
    local slug="$1"
    check_start "${slug}"
    
    # Формируем URL для проверки
    local health_url="${BASE_URL}${PING_API}"
    
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
export -f check_start check_success check_fail perform_healthcheck
export BASE_URL PING_API
