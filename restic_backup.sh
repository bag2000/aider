#!/bin/bash

set -e
set -o pipefail

# Функция для выполнения резервного копирования
run_restic_backup() {   
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
    
    # Инициализация репозитория, если он ещё не создан
    if ! restic snapshots &> /dev/null; then
        echo "Репозиторий не инициализирован или недоступен. Попытка инициализации..." >&2
        if restic init; then
            echo "Репозиторий успешно инициализирован." >&2
        else
            echo "ОШИБКА: не удалось инициализировать репозиторий." >&2
            exit 1
        fi
    fi
    
    echo "Начало резервного копирования..." >&2
    
    # Сбор аргументов для команды backup с использованием массива
    local backup_cmd_args=("backup")
    
    # Добавляем пути для резервного копирования
    read -ra backup_paths <<< "${BACKUP_PATHS}"
    for path in "${backup_paths[@]}"; do
        backup_cmd_args+=("$path")
    done
    
    # Добавляем параметры из конфигурации
    backup_cmd_args+=("--cache-dir=${base_dir}/${RESTIC_CACHE_DIR}")
    
    local exclude_file="${base_dir}/${EXCLUDE_FILE}"
    if [[ -f "$exclude_file" ]]; then
        backup_cmd_args+=("--exclude-file=${exclude_file}")
    fi
    
    backup_cmd_args+=("--pack-size=${RESTIC_PACK_SIZE}")
    
    # Выполнение команды
    if restic "${backup_cmd_args[@]}" 2>&1; then
        echo "Резервное копирование успешно завершено." >&2
    else
        echo "ОШИБКА: резервное копирование завершилось с ошибкой." >&2
        exit 1
    fi
}

# Если скрипт запущен напрямую, а не через source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Этот скрипт предназначен для подключения через source, а не для прямого выполнения." >&2
    exit 1
fi
