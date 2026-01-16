# Скрипты для логирования и heartbeat

## log.sh

Логирование в файл и терминал.

### Использование

```bash
# Подключить в своём скрипте
source /путь/log.sh

# Использовать функции
log_info "Сообщение"
log_success "Успех"
log_warn "Предупреждение"
log_error "Ошибка"
```

Переменные окружения:
- `LOG_PATH` – путь к файлу лога (по умолчанию `./logs/script.log`)

## hc.sh

Отправка Healthchecks в Healthchecks.io.

### Требования

Перед использованием **обязательно** задайте переменные окружения:
```bash
export HC_BASE_URL="https://hc.t8.ru/ping"
export HC_PING_API="ваш_ключ"
```

### Использование как отдельный скрипт

```bash
chmod +x hc.sh
./hc.sh check_success my-slug
./hc.sh check_start my-slug
./hc.sh check_fail my-slug
```

### Использование через source

```bash
# Задать переменные ДО подключения
export HC_BASE_URL="https://hc.t8.ru/ping"
export HC_PING_API="ваш_ключ"
source ./hc.sh

# Вызывать функции
check_success my-slug
check_start my-slug
check_fail my-slug
```

### Переменные окружения
- `HC_BASE_URL` – базовый URL (обязательно)
- `HC_PING_API` – ключ API (обязательно)
- `HC_DNS` – DNS override для curl (например `192.168.1.1:443:hc.t8.ru`, необязательно)

## Пример

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

source ./log.sh
export HC_BASE_URL="https://hc.t8.ru/ping"
export HC_PING_API="qpljt3jgl2inp8lkya6h1a"
source ./hc.sh

log_info "Начинаем задачу"
check_start "backup-job"

# выполнение задачи...

if [ $? -eq 0 ]; then
    check_success "backup-job"
    log_success "Задача завершена"
else
    check_fail "backup-job"
    log_error "Задача не удалась"
fi
```
