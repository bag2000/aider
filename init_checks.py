#!/usr/bin/env python3
"""
Инициализация чеков Healthchecks на основе конфигурации init.conf.
"""

import sys
import config_manager
from hc import add_check
from logger_manager import log


def init_checks(token: str, base_url_override: str = None):
    """
    Создаёт чеки Healthchecks для всех включённых задач в init.conf.

    Args:
        token (str): API токен Healthchecks.
        base_url_override (str, optional): Переопределение base_url из командной строки.
                                           Если None, используется значение из конфигурации.
    """
    # Загружаем конфигурацию
    config_manager.load_config()
    general = config_manager.get_general_settings()
    server_name = general.get('server_name')
    if not server_name:
        print("Ошибка: server_name не указан в секции general", file=sys.stderr)
        sys.exit(1)

    # Определяем base_url: приоритет у переопределения, затем конфигурация
    default_base = "https://healthchecks.io/api/v1/checks/"
    if base_url_override and base_url_override != default_base:
        base_url = base_url_override
    else:
        base_url = general.get('base_url', default_base)

    ping_base = general.get('ping_base', 'https://hc-ping.com')
    channels = general.get('channels', '')
    log.info(f"Используемый base_url: {base_url}")
    log.info(f"Используемый ping_base: {ping_base}")
    log.info(f"Используемые каналы: {channels if channels else '(пусто)'}")

    # Получаем включённые задачи
    try:
        tasks = config_manager.get_enabled_tasks()
    except SystemExit:
        # Если секция tasks отсутствует, выходим
        print("Ошибка: не удалось получить список задач", file=sys.stderr)
        sys.exit(1)

    if not tasks:
        log.warning("Нет включённых задач для создания чеков.")
        sys.exit(0)

    log.info(f"Создание чеков для сервера: {server_name}")
    log.info(f"Найдено включённых задач: {len(tasks)}")

    for task in tasks:
        task_slug = task.get('slug')
        if not task_slug:
            log.warning(f"У задачи '{task.get('name')}' отсутствует slug, пропускаем.")
            continue

        full_slug = f"{server_name}-{task_slug}"
        task_tag = task.get('tag', 'prod www')
        log.info(f"Создание чека для задачи: {task.get('name')} (slug: {full_slug}, tags: {task_tag})")

        # Определяем теги для чека
        task_tag = task.get('tag', 'prod www')
        try:
            result = add_check(
                token=token,
                name=full_slug,  # Имя чека должно совпадать со slug
                tags=task_tag,
                timeout=3600,
                grace=60,
                channels=channels,
                base_url=base_url,
                slug=full_slug,
            )
            log.info(f"Результат: {result['status']}")
            if 'check' in result and 'ping_url' in result['check']:
                log.info(f"Ping URL: {result['check']['ping_url']}")
        except Exception as e:
            log.error(f"Ошибка при создании чека: {e}")

    log.info("Инициализация завершена.")


def main():
    """
    Точка входа для запуска скрипта напрямую.
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Инициализация чеков Healthchecks для включённых задач резервного копирования."
    )
    parser.add_argument("token",
                        help="API токен Healthchecks")
    parser.add_argument("--base-url", default="https://healthchecks.io/api/v1/checks/",
                        help="Базовый URL API Healthchecks (по умолчанию: %(default)s)")
    args = parser.parse_args()

    init_checks(args.token, args.base_url)


if __name__ == "__main__":
    main()
