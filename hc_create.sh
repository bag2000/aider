#!/usr/bin/env bash
# Скрипт для создания healthcheck через API
# Можно использовать как отдельный скрипт или подключать через source

set -Eeuo pipefail

# Конфигурация
HC_CREATE_NAME="test"
HC_CREATE_API_URL="https://hc.t8.ru/api/v3/checks/"
HC_CREATE_API_TOKEN="hcw_0CJLKZQGcMQe4OGC9ws5qP4sJnjb"
HC_CREATE_CHANNELS="319329f7-0060-4219-8fd8-6f8a1d1f2258,abbddf53-8bf5-47bf-bc85-e79d99d08c70"
HC_CREATE_DESCRIPTION="Тестовое описание"
HC_CREATE_TAGS="prod test"
HC_CREATE_TIMEOUT=86400
HC_CREATE_GRACE=60

# Файл для хранения ID созданного чека
ID_FILE=".id_healthcheck"

# Функция логирования
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# Функция создания чека через API
create_healthcheck() {
    local name="$1"
    local slug="$2"
    local tags="$3"
    local desc="$4"
    local timeout="$5"
    local grace="$6"
    local api_url="$7"
    local api_token="$8"
    local channels="$9"

    # Подготовка данных для отправки
    local json_data
    json_data=$(cat <<EOF
{
    "name": "${name}",
    "slug": "${slug}",
    "tags": "${tags}",
    "desc": "${desc}",
    "timeout": ${timeout},
    "grace": ${grace},
    "channels": "${channels}"
}
EOF
    )

    log_info "Отправка запроса на создание чека: ${name}"

    # Отправка POST запроса
    local response
    if ! response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: ${api_token}" \
        -d "${json_data}" \
        "${api_url}" 2>&1); then
        log_error "Ошибка при выполнении curl: ${response}"
        return 1
    fi

    # Проверка ответа
    if echo "${response}" | grep -q "error"; then
        log_error "API вернуло ошибку: ${response}"
        return 1
    fi

    # Извлечение ID из ответа (предполагаем, что ответ в JSON и содержит поле "id")
    local check_id
    if check_id=$(echo "${response}" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4); then
        if [ -n "${check_id}" ]; then
            echo "${check_id}" > "${ID_FILE}"
            log_info "Чек успешно создан с ID: ${check_id}"
            log_info "ID сохранён в файл: ${ID_FILE}"
            return 0
        fi
    fi

    # Если не удалось извлечь ID, попробуем другой подход
    log_info "Ответ API: ${response}"
    log_error "Не удалось извлечь ID чека из ответа API"
    return 1
}

# Основная функция
main() {
    log_info "Проверка наличия файла ${ID_FILE}"

    if [ -f "${ID_FILE}" ]; then
        local existing_id
        existing_id=$(cat "${ID_FILE}" 2>/dev/null || echo "")
        if [ -n "${existing_id}" ]; then
            log_info "Файл ${ID_FILE} уже существует с ID: ${existing_id}"
            log_info "Создание чека пропущено"
            return 0
        else
            log_info "Файл ${ID_FILE} существует, но пуст. Удаляем его."
            rm -f "${ID_FILE}"
        fi
    fi

    log_info "Файл ${ID_FILE} не найден. Создаём новый чек."

    # Создание чека
    if create_healthcheck \
        "${HC_CREATE_NAME}" \
        "${HC_CREATE_NAME}" \
        "${HC_CREATE_TAGS}" \
        "${HC_CREATE_DESCRIPTION}" \
        "${HC_CREATE_TIMEOUT}" \
        "${HC_CREATE_GRACE}" \
        "${HC_CREATE_API_URL}" \
        "${HC_CREATE_API_TOKEN}" \
        "${HC_CREATE_CHANNELS}"; then
        log_info "Чек успешно создан"
    else
        log_error "Не удалось создать чек"
        return 1
    fi
}

# Если скрипт запущен напрямую, а не подключен через source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
