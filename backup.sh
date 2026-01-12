#!/bin/bash

# Скрипт резервного копирования с использованием restic
# Предназначен для запуска через cron на удалённом сервере

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

# Настройки репозитория restic
# Укажите путь к репозиторию (локальный, SFTP, S3 и т.д.)
export RESTIC_REPOSITORY="/path/to/your/restic/repository"
# Укажите файл с паролем репозитория (или используйте переменную RESTIC_PASSWORD)
export RESTIC_PASSWORD_FILE="/path/to/restic/password/file"
# Альтернативно можно задать пароль напрямую через переменную (менее безопасно):
# export RESTIC_PASSWORD="your_password"

# Если используется SFTP или удалённый репозиторий, может потребоваться указать дополнительные переменные
# export RESTIC_SFTP_USER="username"
# export RESTIC_SFTP_HOST="hostname"
# export RESTIC_SFTP_PORT="22"

# Пути для резервного копирования (укажите свои директории)
BACKUP_PATHS=(
    "/home"
    "/etc"
    "/var/www"
)

# Исключения (опционально)
EXCLUDE_FILE="/path/to/exclude/file.txt"  # файл с шаблонами исключений, если нужен

# Проверка настроек репозитория
if [[ -z "$RESTIC_REPOSITORY" ]]; then
    log "ОШИБКА: переменная RESTIC_REPOSITORY не установлена."
    exit 1
fi

if [[ ! -f "$RESTIC_PASSWORD_FILE" ]] && [[ -z "$RESTIC_PASSWORD" ]]; then
    log "ОШИБКА: не задан пароль репозитория (ни через RESTIC_PASSWORD_FILE, ни через RESTIC_PASSWORD)."
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

# Сбор аргументов для команды backup
BACKUP_CMD="restic backup"
for path in "${BACKUP_PATHS[@]}"; do
    BACKUP_CMD+=" \"$path\""
done

if [[ -f "$EXCLUDE_FILE" ]]; then
    BACKUP_CMD+=" --exclude-file=\"$EXCLUDE_FILE\""
fi

# Выполнение команды
if eval "$BACKUP_CMD" 2>&1 | tee -a "$LOG_FILE"; then
    log "Резервное копирование успешно завершено."
else
    log "ОШИБКА: резервное копирование завершилось с ошибкой."
    exit 1
fi

# Очистка старых снимков (опционально)
# Политика хранения: оставлять последние 7 ежедневных, 4 еженедельных, 6 ежемесячных и 2 ежегодных снимка
log "Запуск очистки старых снимков..."
if restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 2 --prune 2>&1 | tee -a "$LOG_FILE"; then
    log "Очистка старых снимков успешно завершена."
else
    log "ОШИБКА: очистка старых снимков завершилась с ошибкой."
    exit 1
fi

log "Все операции резервного копирования завершены."
exit 0
