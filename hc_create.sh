#!/bin/bash

# Определяем директорию скрипта для относительных путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загружаем конфигурацию и функции логирования
source "${SCRIPT_DIR}/.env" || { echo "Failed to load .env"; exit 1; }
source "${SCRIPT_DIR}/log.sh" || { echo "Failed to load log.sh"; exit 1; }

hc_create() {
    # Формирование JSON данных для запроса
    json_data=$(cat <<EOF
{
    "name": "${HC_CREATE_NAME}",
    "slug": "${HC_CREATE_NAME}",
    "tags": "${HC_CREATE_TAGS}",
    "desc": "${HC_CREATE_DESC}",
    "timeout": ${HC_CREATE_TIMEOUT},
    "grace": ${HC_CREATE_GRACE},
    "channels": "${HC_CREATE_CHANNELS}",
    "unique" : ${HC_CREATE_UNIQUE}
}
EOF
    )

    # Полный путь к файлу с UUID
    ID_FILE_PATH="${SCRIPT_DIR}/${HC_CREATE_ID_FILE}"

    # Проверка существования файла с UUID
    if [ -f "$ID_FILE_PATH" ]; then
        log_info "[$HC_CREATE_LOGNAME] Файл $ID_FILE_PATH существует. Пропускаю создание чека $HC_CREATE_NAME"
        return 0
    fi

    log_info "[$HC_CREATE_LOGNAME] Файл $ID_FILE_PATH не существует. Создаю чек $HC_CREATE_NAME"
    
    # Отправка POST запроса для создания чека
    if ! response=$(curl --resolve $HC_CREATE_DNS -s -f -X POST \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: ${HC_CREATE_API_TOKEN}" \
        -d "${json_data}" \
        "${HC_CREATE_API_URL}" 2>&1); then
        log_error "[$HC_CREATE_LOGNAME] Ошибка при выполнении curl"
        return 1
    fi
    
    # Проверка ответа сервера
    if [ -z "$response" ]; then
        log_error "[$HC_CREATE_LOGNAME] Получен пустой ответ от сервера"
        return 1
    fi
    
    # Извлечение UUID из JSON ответа
    uuid=$(echo "$response" | grep -o '"uuid": "[^"]*"' | cut -d'"' -f4)
    
    # Валидация извлеченного UUID
    if [ -z "$uuid" ]; then
        log_error "[$HC_CREATE_LOGNAME] Не удалось извлечь UUID из ответа"
        return 1
    fi
    
    # Сохранение UUID в файл для последующего использования
    echo "$uuid" > "$ID_FILE_PATH"
    log_info "[$HC_CREATE_LOGNAME] Чек создан, UUID сохранен: $uuid"
    
    return 0
}