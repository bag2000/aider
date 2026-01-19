# Используй логирование
source ./log.sh || { echo "Failed to load log.sh"; exit 1; }
Функции логирования вместо echo:
  - log_info "текст"
  - log_success "текст"
  - log_error "текст" (stderr)
  - log_warn "текст" (stderr)
Примеры:
  - log_info "Начинаю обработку..."
  - log_error "Ошибка" && exit 1