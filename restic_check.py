#!/usr/bin/env python3
"""
Скрипт для выполнения проверки репозитория restic.
Использует конфигурацию из init.conf и отправляет ping-сигналы в Healthchecks.
"""

import sys
import os
import config_manager
from hc import ping_start, ping_success, ping_fail
from logger_manager import log
from shell_manager import run_command_with_user


def construct_ping_url(ping_base, server_name, task_slug):
    """
    Формирует полный ping URL для задачи.
    """
    base = ping_base.rstrip('/')
    return f"{base}/{server_name}-{task_slug}"


def run_restic_check(task, general_settings):
    """
    Выполняет команду restic check для одной задачи.
    """
    task_name = task.get('name', 'Без имени')
    task_slug = task.get('slug')
    bin_path = task.get('bin_path', '/usr/bin/restic')
    args = task.get('args', 'check')
    sys_user = task.get('sys_user', '')
    backup_path = general_settings.get('backup_path')
    server_name = general_settings.get('server_name')
    ping_base = general_settings.get('ping_base', 'https://hc-ping.com')

    # Получаем настройки restic из general
    restic_repository = general_settings.get('restic_repository', '/path/to/repo')
    restic_password_file = general_settings.get('restic_password_file', '.restic_pass')
    restic_cache_dir = general_settings.get('restic_cache_dir', 'cache')
    restic_pack_size = general_settings.get('restic_pack_size', '128')
    exclude_file = general_settings.get('exclude_file', 'exclude.txt')

    log.info(f"Начинаем проверку restic: {task_name}")

    # Проверка обязательных параметров
    if not all([task_slug, bin_path]):
        log.error(f"Задача '{task_name}' пропущена: отсутствуют обязательные параметры.")
        return False

    # Формируем ping URL
    ping_url = construct_ping_url(ping_base, server_name, task_slug)
    log.info(f"Ping URL для задачи: {ping_url}")

    # Отправляем start ping
    try:
        ping_start(ping_url, data=f"Начало проверки restic: {task_name}")
        log.info("Отправлен start ping.")
    except Exception as e:
        log.warning(f"Не удалось отправить start ping: {e}")

    # Формируем переменные окружения для restic
    env = os.environ.copy()
    env['RESTIC_REPOSITORY'] = restic_repository
    env['RESTIC_PASSWORD_FILE'] = restic_password_file
    env['RESTIC_CACHE_DIR'] = restic_cache_dir
    # RESTIC_PACK_SIZE обычно не требуется для check, но можно установить
    # env['RESTIC_PACK_SIZE'] = restic_pack_size

    # Формируем команду
    cmd = f"{bin_path} {args}"
    log.info(f"Выполняем команду: {cmd}")

    # Выполняем команду
    success, output = run_command_with_user(cmd, sys_user, env=env)

    if success:
        log.info(f"Проверка restic выполнена успешно: {task_name}")
        try:
            ping_success(ping_url, data=f"Проверка restic {task_name} завершена успешно")
            log.info("Отправлен success ping.")
        except Exception as e:
            log.warning(f"Не удалось отправить success ping: {e}")
        return True
    else:
        log.error(f"Ошибка при проверке restic: {output}")
        try:
            ping_fail(ping_url, data=f"Ошибка при проверке restic: {output}")
        except Exception as e:
            log.warning(f"Не удалось отправить fail ping: {e}")
        return False


def main():
    """
    Основная функция скрипта.
    """
    log.info("Запуск скрипта проверки restic.")

    # Загружаем конфигурацию
    try:
        config_manager.load_config()
        general_settings = config_manager.get_general_settings()
        tasks = config_manager.get_enabled_tasks()
    except SystemExit as e:
        log.error(f"Ошибка загрузки конфигурации: {e}")
        sys.exit(1)

    # Фильтруем задачи, относящиеся к restic (db_type == "restic" или bin_path содержит restic)
    restic_tasks = []
    for task in tasks:
        db_type = task.get('db_type', '')
        bin_path = task.get('bin_path', '')
        if db_type == 'restic' or 'restic' in bin_path:
            restic_tasks.append(task)

    if not restic_tasks:
        log.warning("Нет включённых задач для проверки restic.")
        sys.exit(0)

    log.info(f"Найдено {len(restic_tasks)} задач restic.")

    # Выполняем проверку для каждой задачи
    results = []
    for task in restic_tasks:
        success = run_restic_check(task, general_settings)
        results.append((task.get('name'), success))

    # Итоговый отчёт
    log.info("=" * 50)
    log.info("ИТОГ ВЫПОЛНЕНИЯ:")
    for task_name, success in results:
        status = "УСПЕХ" if success else "ОШИБКА"
        log.info(f"  {task_name}: {status}")

    # Если хотя бы одна задача завершилась неудачно, завершаем с кодом ошибки
    if any(not success for _, success in results):
        log.error("Некоторые задачи проверки restic завершились с ошибкой.")
        sys.exit(1)
    else:
        log.info("Все задачи проверки restic выполнены успешно.")
        sys.exit(0)


if __name__ == "__main__":
    main()
