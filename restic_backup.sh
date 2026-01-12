#!/bin/bash

# Скрипт резервного копирования с использованием restic

# Проверка, что скрипт запущен от root
if [[ $EUID -ne 0 ]]; then
   echo "ОШИБКА: Этот скрипт должен быть запущен с правами root." >&2
   exit 1
fi

# Путь к лог-файлу
LOG_FILE="/var/log/restic_backup.log"

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Проверка наличия restic
if ! command -v restic &> /dev/null; then
    log "ОШИБКА: restic не найден. Установите restic перед запуском скрипта."
    exit 1
fi

# Пути для резервного копирования
if [[ -n "${BACKUP_PATHS_ENV}" ]]; then
    # Преобразуем строку в массив
    read -ra BACKUP_PATHS <<< "${BACKUP_PATHS_ENV}"
else
    # Значения по умолчанию
    BACKUP_PATHS=(
        "/"
    )
fi

# Проверка настроек репозитория
if [[ -z "$RESTIC_REPOSITORY" ]]; then
    log "ОШИБКА: переменная RESTIC_REPOSITORY не установлена."
    exit 1
fi

if [[ -z "$RESTIC_PASSWORD" ]]; then
    log "ОШИБКА: не задан пароль репозитория."
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

# Выполнение резервного копирования
log "Начало резервного копирования..."

# Сбор аргументов для команды backup с использованием массива
BACKUP_CMD_ARGS=("backup")
for path in "${BACKUP_PATHS[@]}"; do
    BACKUP_CMD_ARGS+=("$path")
done

if [[ -f "$EXCLUDE_FILE" ]]; then
    BACKUP_CMD_ARGS+=("--exclude-file=$EXCLUDE_FILE")
fi

# Выполнение команды
if restic "${BACKUP_CMD_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"; then
    log "Резервное копирование успешно завершено."
else
    log "ОШИБКА: резервное копирование завершилось с ошибкой."
    exit 1
fi
