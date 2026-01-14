import requests


def add_check(
    *,
    token: str,
    name: str,
    tags: str,
    timeout: int,
    grace: int,
    channels: str,
    base_url: str,
) -> dict:
    """
    Create Healthchecks check if it does not exist.
    """

    headers = {
        "X-Api-Key": token,
        "Content-Type": "application/json",
    }

    payload = {
        "name": name,
        "slug": name,
        "tags": tags,
        "timeout": timeout,
        "grace": grace,
        "channels": channels,
    }

    with requests.Session() as session:
        session.headers.update(headers)

        # check existence
        response = session.get(base_url, params={"slug": name}, timeout=10)
        response.raise_for_status()
        checks = response.json().get("checks", [])

        if checks:
            return {
                "status": "exists",
                "check": checks[0],
            }

        # create check
        response = session.post(base_url, json=payload, timeout=10)
        response.raise_for_status()

        return {
            "status": "created",
            "check": response.json(),
        }


def ping_start(ping_url: str, data: str = None) -> None:
    """
    Send a start signal to Healthchecks.
    """
    url = f"{ping_url}/start"
    _send_ping(url, data)


def ping_success(ping_url: str, data: str = None) -> None:
    """
    Send a success signal to Healthchecks.
    """
    _send_ping(ping_url, data)


def ping_fail(ping_url: str, data: str = None) -> None:
    """
    Send a fail signal to Healthchecks.
    """
    url = f"{ping_url}/fail"
    _send_ping(url, data)


def _send_ping(url: str, data: str = None) -> None:
    """
    Internal helper to send a POST request to a Healthchecks ping endpoint.
    """
    with requests.Session() as session:
        if data is not None:
            response = session.post(url, data=data.encode("utf-8"), timeout=10)
        else:
            response = session.post(url, timeout=10)
        response.raise_for_status()


if __name__ == "__main__":
    """
    Пример использования модуля hc.
    Замените значения на свои перед запуском.
    """
    import logging
    import sys

    # Настройка логирования для вывода информации
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        stream=sys.stdout,
    )
    logger = logging.getLogger(__name__)

    # Конфигурация (замените на реальные значения)
    API_TOKEN = "ваш_api_токен_healthchecks"
    BASE_URL = "https://healthchecks.io/api/v1/checks/"
    PING_BASE = "https://hc-ping.com"

    # Параметры нового чека
    check_name = "example_check"
    tags = "prod,backup"
    timeout_seconds = 3600
    grace_seconds = 300
    channels = ""  # можно указать идентификаторы каналов через запятую

    try:
        logger.info("1. Создание чека (если не существует)...")
        result = add_check(
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

        logger.info(f"   Ping URL: {ping_url}")

        # Пример отправки сигналов
        logger.info("2. Отправка сигнала 'start'...")
        ping_start(ping_url, data="Задача начата")
        logger.info("   Сигнал start отправлен")

        # Имитация работы задачи
        logger.info("3. Выполнение задачи...")
        # ... здесь код вашей задачи ...

        # В зависимости от результата отправляем success или fail
        task_succeeded = True  # замените на реальный результат
        if task_succeeded:
            logger.info("4. Отправка сигнала 'success'...")
            ping_success(ping_url, data="Задача успешно завершена")
            logger.info("   Сигнал success отправлен")
        else:
            logger.warning("4. Отправка сигнала 'fail'...")
            ping_fail(ping_url, data="Задача завершилась с ошибкой")
            logger.warning("   Сигнал fail отправлен")

        logger.info("Пример выполнен. Проверьте статус на Healthchecks.")

    except Exception as e:
        logger.error(f"Ошибка при выполнении примера: {e}", exc_info=True)
        sys.exit(1)
