#!/bin/bash

set -e
set -o pipefail

# Функция для очистки старых снимков
run_restic_forget() {
    # Определяем BASE_DIR из main.sh через глобальную переменную или вычисляем
    local base_dir="${BASE_DIR:-$(dirname "$(readlink -f "$0")")}"
    
    # Проверка наличия restic
    if ! command -v restic &> /dev/null; then
        echo "ОШИБКА: restic не найден. Установите restic перед запуском скрипта." >&2
        exit 1
    fi
    
    # Проверка настроек репозитория
    if [[ -z "$RESTIC_REPOSITORY" ]]; then
        echo "ОШИБКА: переменная RESTIC_REPOSITORY не установлена." >&2
        exit 1
    fi
    
    echo "Начало очистки старых снимков..." >&2
    
    # Сбор аргументов для команды forget с использованием массива
    local forget_cmd_args=("forget")
    
    # Добавляем политики хранения
    forget_cmd_args+=("--keep-daily" "$RETENTION_DAYS")
    forget_cmd_args+=("--keep-weekly" "$RETENTION_WEEKS")
    forget_cmd_args+=("--keep-monthly" "$RETENTION_MONTH")
    forget_cmd_args+=("--keep-yearly" "$RETENTION_YEAR")
    
    # Добавляем параметры из конфигурации
    forget_cmd_args+=("--prune")
    forget_cmd_args+=("--cache-dir=${base_dir}/${RESTIC_CACHE_DIR}")
    forget_cmd_args+=("--pack-size=${RESTIC_PACK_SIZE}")
    
    # Выполнение команды
    if restic "${forget_cmd_args[@]}" 2>&1; then
        echo "Очистка старых снимков успешно завершена." >&2
    else
        echo "ОШИБКА: очистка старых снимков завершилась с ошибкой." >&2
        exit 1
    fi
}

# Если скрипт запущен напрямую, а не через source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Этот скрипт предназначен для подключения через source, а не для прямого выполнения." >&2
    exit 1
fi
