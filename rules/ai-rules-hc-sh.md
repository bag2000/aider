# Используй healtcheck
source ./hc.sh || { echo "Failed to load log.sh"; exit 1; }
- Начало: check_start "slug"
- Успех: check_success "slug"
- Ошибка: check_fail "slug"