#!/bin/bash

# Цвета ANSI
RED='\033[0;31m'    # Обычный красный
GREEN='\033[0;32m'  # Обычный зеленый
YELLOW='\033[0;33m' # Обычный желтый
BLUE='\033[0;34m'   # Обычный синий
NC='\033[0m'        # Сброс цвета

# Загружаем .env из той же директории что и скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env" || exit 1

# Устанавливаем значения по умолчанию для опциональных переменных
: "${LOG_TIMESTAMP_FORMAT:="%d.%m.%Y %H:%M:%S"}"
: "${LOG_COLORS:="true"}"
: "${LOG_DIR:="./logs"}"
: "${LOG_FILE:="app.log"}"

# Подготовка директории и пути к лог-файлу
mkdir -p "$LOG_DIR"
LOG_PATH="${LOG_DIR}/${LOG_FILE}"


# синий текст
log_debug() {
    local msg="$1"
    local entry="$(date "+$LOG_TIMESTAMP_FORMAT") [DEBUG] $msg"
    
    # Запись в файл
    echo "$entry" >> "$LOG_PATH"

    # Вывод в консоль с цветом
    [[ "$LOG_COLORS" == "true" ]] && echo -e "${BLUE}${entry}${NC}" || echo "$entry"
}


# обычный цвет
log_info() {
    local msg="$1"
    local entry="$(date "+$LOG_TIMESTAMP_FORMAT") [INFO] $msg"
    
    # Запись в файл
    echo "$entry" >> "$LOG_PATH"

    # Вывод в консоль обычным цветом
    echo "${entry}"
}

# красный текст
log_error() {
    local msg="$1"
    local entry="$(date "+$LOG_TIMESTAMP_FORMAT") [ERROR] $msg"
    
    # Запись в файл
    echo "$entry" >> "$LOG_PATH"
    
    # Вывод в консоль с цветом
    [[ "$LOG_COLORS" == "true" ]] && echo -e "${RED}${entry}${NC}"|| echo "$entry"
}

# зеленый текст
log_success() {
    local msg="$1"
    local entry="$(date "+$LOG_TIMESTAMP_FORMAT") [SUCCESS] $msg"
    
    # Запись в файл
    echo "$entry" >> "$LOG_PATH"

    # Вывод в консоль с цветом
    [[ "$LOG_COLORS" == "true" ]] && echo -e "${GREEN}${entry}${NC}" || echo "$entry"
}

# желтый текст
log_warning() {
    local msg="$1"
    local entry="$(date "+$LOG_TIMESTAMP_FORMAT") [WARNING] $msg"
    
    # Запись в файл
    echo "$entry" >> "$LOG_PATH"

    # Вывод в консоль с цветом
    [[ "$LOG_COLORS" == "true" ]] && echo -e "${YELLOW}${entry}${NC}" || echo "$entry"
}

# Экспортируем все функции
export -f log_debug log_info log_error log_success log_warning

# Если скрипт вызван с аргументами
if [[ $# -gt 0 ]]; then
    case "$1" in
        debug) log_debug "${*:2}" ;;
        info) log_info "${*:2}" ;;
        error) log_error "${*:2}" ;;
        success) log_success "${*:2}" ;;
        warning) log_warning "${*:2}" ;;
        *) 
            echo "Использование: $0 {debug|info|error|success|warning} сообщение"
            exit 1
            ;;
    esac
else
    # Показываем справку если нет аргументов
    echo "=== ЛОГГЕР v1.0 ==="
    echo ""
    echo "Доступные функции:"
    echo "  log_debug    - синий текст (отладочная информация)"
    echo "  log_info     - обычный текст (информационные сообщения)"
    echo "  log_success  - зеленый текст (успешные операции)"
    echo "  log_warning  - желтый текст (предупреждения)"
    echo "  log_error    - красный текст (ошибки)"
    echo ""
    echo "Использование из командной строки:"
    echo "  $0 {debug|info|error|success|warning} \"сообщение\""
    echo ""
    echo "Примеры командной строки:"
    echo "  $0 info \"Скрипт запущен\""
    echo "  $0 error \"Критическая ошибка\""
    echo "  $0 success \"Операция завершена\""
    echo ""
    echo "Использование в bash-скриптах:"
    echo "  # Подключение логгера"
    echo "  source $(basename "$0")"
    echo ""
    echo "  # Получение имени текущего скрипта"
    echo '  SCRIPT_NAME=$(basename "$0")'
    echo ""
    echo "  # Примеры использования:"
    echo '  log_info "[$SCRIPT_NAME] Скрипт запущен"'
    echo '  log_success "[$SCRIPT_NAME] Операция выполнена"'
    echo '  log_error "[$SCRIPT_NAME] Ошибка в функции process_data()"'
    echo ""
    echo "Настройки в файле .env:"
    echo "  LOG_DIR              - директория для логов (по умолчанию: ./logs)"
    echo "  LOG_FILE             - имя файла лога (по умолчанию: app.log)"
    echo "  LOG_COLORS           - цветной вывод (true/false, по умолчанию: true)"
    echo "  LOG_TIMESTAMP_FORMAT - формат времени"
fi