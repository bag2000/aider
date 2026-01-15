#!/bin/bash

# Подключаем логгер
source "$(dirname "$0")/log.sh" 2>/dev/null || {
    echo "Ошибка: Не найден log.sh" >&2
    exit 1
}


# Простая проверка healthcheck
check_start() {
    local url="$1"
    
    # Проверяем существует ли URL
    curl $url
    if [[ $(curl "$url" | grep "resource was not found" | wc -l) ]]; then
        log_info "Healthcheck доступен: $url"
    fi
}

export -f check_start