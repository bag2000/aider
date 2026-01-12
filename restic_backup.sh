#!/bin/bash

set -e
set -o pipefail

# Функция для выполнения резервного копирования
run_restic_backup() {   
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
    
    # Инициализация репозитория, если он ещё не создан
    if ! restic snapshots &> /dev/null; then
        log "Репозиторий не инициализирован или недоступен. Попытка инициализации..."
        if restic init; then
            log "Репозиторий успешно инициализирован."
        else
            log "ОШИБКА: не удалось инициализировать репозиторий."
            exit 1
        fi
    fi
    
    log "Начало резервного копирования..."
    
    # Сбор аргументов для команды backup с использованием массива
    local backup_cmd_args=("backup")
    
    # Добавляем пути для резервного копирования
    read -ra backup_paths <<< "${BACKUP_PATHS}"
    for path in "${backup_paths[@]}"; do
        backup_cmd_args+=("$path")
    done
    
    # Добавляем параметры из конфигурации
    backup_cmd_args+=("--cache-dir=${RESTIC_CACHE_DIR}")
    
    if [[ -f "${ABS_EXCLUDE_FILE}" ]]; then
        backup_cmd_args+=("--exclude-file=${ABS_EXCLUDE_FILE}")
    fi
    
    backup_cmd_args+=("--pack-size=${RESTIC_PACK_SIZE}")
    
    # Объявление переменной для сохранения exit статуса
    local restic_exit_code

    # Запускаем restic
    restic "${backup_cmd_args[@]}" 2>&1 --one-file-system | tee -a "$ABS_LOG_FILE"
    restic_exit_code=${PIPESTATUS[0]}

    # Проверяем код возврата
    if [[ $restic_exit_code -eq 0 ]]; then
        log "Резервное копирование успешно завершено."
    else
        log "ОШИБКА: резервное копирование завершилось с ошибкой (код: $restic_exit_code)."
        exit 1
    fi
}

# Если скрипт запущен напрямую, а не через source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Этот скрипт предназначен для подключения через source, а не для прямого выполнения." >&2
    exit 1
fi
