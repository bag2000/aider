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

Отправка heartbeat в Healthchecks.io.

### Требования

Перед использованием **обязательно** задайте переменную окружения:
```bash
export PING_API="ваш_ключ"
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
# Задать ключ ДО подключения
export PING_API="ваш_ключ"
source ./hc.sh

# Вызывать функции
check_success my-slug
check_start my-slug
check_fail my-slug
```

### Переменные окружения
- `PING_API` – ключ API (обязательно)
- `BASE_URL` – базовый URL (по умолчанию `https://hc.t8.ru/ping`)

## Пример

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

source ./log.sh
export PING_API="qpljt3jgl2inp8lkya6h1a"
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
