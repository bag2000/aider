#!/bin/bash

# Определяем директорию скрипта для относительных путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загружаем конфигурацию и функции логирования
source "${SCRIPT_DIR}/.env" || { echo "Failed to load .env"; exit 1; }
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

# Полный путь к файлу с UUID
ID_FILE_PATH="${SCRIPT_DIR}/${HC_PING_ID_FILE}"

# Проверка существования файла с UUID
_chech_id_file() {
    if [ -f "$ID_FILE_PATH" ]; then
        log_info "[$HC_PING_LOGNAME] Поучаю UUID из $ID_FILE_PATH"
        uuid=$(cat $ID_FILE_PATH)   # Чтение UUID из файла
        log_info "[$HC_PING_LOGNAME] Получен UUID: $uuid"
    else
        log_error "[$HC_PING_LOGNAME] Файл $ID_FILE_PATH не существует"
        exit 1 # Выход если файл не найден
    fi
}

# Функция отправки start ping (начало выполнения задачи)
hc_ping_start() {
    _chech_id_file
    local message="${1:-}"
    log_info "[$HC_PING_LOGNAME] Отправляю start ping в $HC_PING_URL/$uuid"
    response=$(curl --resolve $HC_PING_DNS --max-time 10 -fs -X POST --data-raw "${message}" "$HC_PING_URL/$uuid/start")
    if [ $response == "OK" ]; then
        log_info "[$HC_PING_LOGNAME] Start ping успешно отправлен"
        return 0
    else
        log_error "[$HC_PING_LOGNAME] Ошибка при отправке start ping"
        return 1
    fi
}

# Функция отправки success ping (успешное завершение задачи)
hc_ping_success() {
    _chech_id_file
    local message="${1:-}"
    log_info "[$HC_PING_LOGNAME] Отправляю succes ping в $HC_PING_URL/$uuid"
    response=$(curl --resolve $HC_PING_DNS --max-time 10 -fs -X POST --data-raw "${message}" "$HC_PING_URL/$uuid")
    if [ $response == "OK" ]; then
        log_info "[$HC_PING_LOGNAME] Succes ping успешно отправлен"
        return 0
    else
        log_error "[$HC_PING_LOGNAME] Ошибка при отправке success ping"
        return 1
    fi
}

# Функция отправки fail ping (ошибка выполнения задачи)
hc_ping_fail() {
    _chech_id_file
    local message="${1:-}"
    log_info "[$HC_PING_LOGNAME] Отправляю fail ping в $HC_PING_URL/$uuid"
    response=$(curl --resolve $HC_PING_DNS --max-time 10 -fs -X POST --data-raw "${message}" "$HC_PING_URL/$uuid/fail")
    if [ $response == "OK" ]; then
        log_info "[$HC_PING_LOGNAME] Fail ping успешно отправлен"
        return 0
    else
        log_error "[$HC_PING_LOGNAME] Ошибка при отправке fail ping"
        return 1
    fi
}
