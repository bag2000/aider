#!/bin/bash

set -e
set -o pipefail

# Функция для очистки старых снимков
run_restic_forget() {
    # Проверка наличия restic
    if ! command -v restic &> /dev/null; then
        log "ОШИБКА: restic не найден. Установите restic перед запуском скрипта."
        exit 1
    fi
    
    # Проверка настроек репозитория
    if [[ -z "$RESTIC_REPOSITORY" ]]; then
        log "ОШИБКА: переменная RESTIC_REPOSITORY не установлена."
        exit 1
    fi
    
    log "Начало очистки старых снимков..."
    
    # Сбор аргументов для команды forget с использованием массива
    local forget_cmd_args=("forget")
    
    # Добавляем политики хранения
    forget_cmd_args+=("--keep-daily" "$RETENTION_DAYS")
    forget_cmd_args+=("--keep-weekly" "$RETENTION_WEEKS")
    forget_cmd_args+=("--keep-monthly" "$RETENTION_MONTH")
    forget_cmd_args+=("--keep-yearly" "$RETENTION_YEAR")
    
    # Добавляем параметры из конфигурации
    forget_cmd_args+=("--prune")
    forget_cmd_args+=("--cache-dir=${RESTIC_CACHE_DIR}")
    forget_cmd_args+=("--pack-size=${RESTIC_PACK_SIZE}")
    
    # Выполнение команды с сохранением вывода
    local restic_output
    local restic_exit_code
    
    # Запускаем restic, захватываем stdout и stderr, сохраняем код возврата
    restic_output=$(restic "${forget_cmd_args[@]}" 2>&1)
    restic_exit_code=$?
    
    # Записываем вывод в лог
    while IFS= read -r line; do
        log "restic: $line"
    done <<< "$restic_output"
    
    # Проверяем код возврата
    if [[ $restic_exit_code -eq 0 ]]; then
        log "Очистка старых снимков успешно завершена."
    else
        log "ОШИБКА: очистка старых снимков завершилась с ошибкой (код: $restic_exit_code)."
        exit 1
    fi
}

# Если скрипт запущен напрямую, а не через source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Этот скрипт предназначен для подключения через source, а не для прямого выполнения." >&2
    exit 1
fi
