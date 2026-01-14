#!/usr/bin/env python3
"""
Тест для модуля hc.
Этот скрипт демонстрирует использование функций add_check, ping_start, ping_success, ping_fail.
Для реального запуска замените фиктивные значения на свои.
"""
import sys
import os
import logging

# Добавляем родительскую директорию в путь, чтобы импортировать hc
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import hc

def main():
    """
    Основная функция теста.
    """
    # Настройка логирования
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        stream=sys.stdout,
    )
    logger = logging.getLogger(__name__)

    # Конфигурация (замените на реальные значения)
    API_TOKEN = ""
    BASE_URL = "https://hc.ext.ru/api/v3/checks/"
    PING_BASE = "https://hc-ping.com"

    # Параметры нового чека
    check_name = "example_check"
    tags = "prod backup" # указываем через пробел
    timeout_seconds = 3600
    grace_seconds = 60
    channels = "319329f7-0060-4219-8fd8-6f8a1d1f2258,abbddf53-8bf5-47bf-bc85-e79d99d08c70"  # можно указать идентификаторы каналов через запятую, слитно

    try:
        logger.info("1. Создание чека (если не существует)...")
        result = hc.add_check(
            token=API_TOKEN,
            name=check_name,
            tags=tags,
            timeout=timeout_seconds,
            grace=grace_seconds,
            channels=channels,
            base_url=BASE_URL,
        )
        logger.info(f"   Результат: {result['status']}")

        # Из ответа получаем ping_url (обычно он есть в объекте чека)
        check_data = result.get("check", {})
        ping_url = check_data.get("ping_url")  # может быть полным URL
        # Если ping_url отсутствует, сформируем его из uuid
        if not ping_url and "uuid" in check_data:
            ping_url = f"{PING_BASE}/{check_data['uuid']}"
        elif not ping_url:
            # В демо-режиме используем фиктивный URL для примера
            ping_url = f"{PING_BASE}/demo-uuid-12345"
            logger.warning(f"   Используется фиктивный ping_url: {ping_url}")

        logger.info(f"   Ping URL: {ping_url}")

        # Пример отправки сигналов
        logger.info("2. Отправка сигнала 'start'...")
        hc.ping_start(ping_url, data="Задача начата")
        logger.info("   Сигнал start отправлен")

        # Имитация работы задачи
        logger.info("3. Выполнение задачи...")
        # ... здесь код вашей задачи ...
        # Для примера просто ждём 5 секунду
        import time
        time.sleep(5)

        # В зависимости от результата отправляем success или fail
        task_succeeded = True  # замените на реальный результат
        if task_succeeded:
            logger.info("4. Отправка сигнала 'success'...")
            hc.ping_success(ping_url, data="Задача успешно завершена")
            logger.info("   Сигнал success отправлен")
        else:
            logger.warning("4. Отправка сигнала 'fail'...")
            hc.ping_fail(ping_url, data="Задача завершилась с ошибкой")
            logger.warning("   Сигнал fail отправлен")

        logger.info("Пример выполнен. Проверьте статус на Healthchecks.")

    except Exception as e:
        logger.error(f"Ошибка при выполнении примера: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
