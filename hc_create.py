#!/usr/bin/env python3
"""
Скрипт для создания healthcheck в healthchecks.io
Использует API для создания проверок с заданными параметрами.

Пример использования:
    python create_healthcheck.py \
        --url "https://hc.exam.ru/api/v3/checks/" \
        --token "hcw_super_token" \
        --name "name_check" \
        --slug "slug_check" \
        --tags "prod restic" \
        --timeout 86400 \
        --grace 3600
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, Optional

import requests

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('logs/hc_create.log', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)


def create_check(
    url: str,
    api_token: str,
    name: str,
    slug: str,
    tags: str = "",
    timeout: int = 86400,
    grace: int = 3600,
    unique: list = None,
    channels: str = ""
) -> Optional[Dict[str, Any]]:
    """
    Создает новую healthcheck проверку через API healthchecks.io
    
    Args:
        url: URL API endpoint
        api_token: API токен
        name: Имя проверки
        slug: Уникальный идентификатор
        tags: Теги через пробел (опционально)
        timeout: Таймаут в секундах (по умолчанию: 86400)
        grace: Время отсрочки в секундах (по умолчанию: 3600)
        unique: Список полей для уникальности (по умолчанию: ["slug"])
        channels: Каналы оповещений (опционально)
    
    Returns:
        Словарь с ответом API или None в случае ошибки
    
    Raises:
        ValueError: При невалидных параметрах
    """
    if unique is None:
        unique = ["slug"]
    
    # Валидация параметров
    if not all([url, api_token, name, slug]):
        logger.error("Обязательные параметры не заполнены")
        raise ValueError("URL, API токен, имя и slug обязательны")
    
    if timeout <= 0 or grace <= 0:
        logger.error("Таймаут и grace должны быть положительными числами")
        raise ValueError("Таймаут и grace должны быть > 0")
    
    # Проверка URL
    if not url.startswith(('http://', 'https://')):
        logger.warning(f"URL '{url}' не начинается с http:// или https://")
    
    # Подготовка заголовков
    headers = {
        "X-Api-Key": api_token,
        "Content-Type": "application/json"
    }
    
    # Подготовка тела запроса
    data = {
        "name": name,
        "slug": slug,
        "tags": tags,
        "timeout": timeout,
        "grace": grace,
        "unique": unique
    }
    
    # Добавляем channels только если указаны
    if channels:
        data["channels"] = channels
    
    logger.info(f"Создаю healthcheck: {name} ({slug})")
    logger.debug(f"URL API: {url}")
    logger.debug(f"Параметры: {json.dumps(data, indent=2)}")
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)
        response.raise_for_status()
        
        result = response.json()
        logger.info(f"Healthcheck создан успешно. ID: {result.get('ping_url', 'N/A')}")
        return result
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Ошибка при выполнении запроса: {e}")
        if hasattr(e, 'response') and e.response is not None:
            logger.error(f"Статус код: {e.response.status_code}")
            logger.error(f"Ответ: {e.response.text}")
    except json.JSONDecodeError as e:
        logger.error(f"Ошибка при разборе JSON ответа: {e}")
    
    return None


def parse_arguments():
    """Парсит аргументы командной строки."""
    parser = argparse.ArgumentParser(
        description="Создание healthcheck в healthchecks.io",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры использования:
    %(prog)s --url https://hc.t8.ru/api/v3/checks/ --token hcw_xxx --name test --slug test_slug
    %(prog)s --url https://hc.t8.ru/api/v3/checks/ --token hcw_xxx --name backup --slug daily_backup --tags "prod cron" --timeout 43200
        """
    )
    
    # Обязательные аргументы
    parser.add_argument(
        "--url",
        required=True,
        help="URL API endpoint (например, https://hc.t8.ru/api/v3/checks/)"
    )
    parser.add_argument(
        "--token",
        required=True,
        help="API токен для аутентификации"
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Имя проверки (человеко-читаемое)"
    )
    parser.add_argument(
        "--slug",
        required=True,
        help="Уникальный идентификатор проверки"
    )
    
    # Опциональные аргументы
    parser.add_argument(
        "--tags",
        default="",
        help="Теги через пробел (например, 'prod backup')"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=86400,
        help="Таймаут в секундах (по умолчанию: 86400 - 24 часа)"
    )
    parser.add_argument(
        "--grace",
        type=int,
        default=3600,
        help="Время отсрочки в секундах (по умолчанию: 3600 - 1 час)"
    )
    parser.add_argument(
        "--channels",
        default="",
        help="Каналы оповещений (опционально)"
    )
    parser.add_argument(
        "--unique",
        nargs="+",
        default=["slug"],
        help="Поля для уникальности (по умолчанию: slug)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Не запрашивать подтверждение (опасно!)"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Файл для сохранения информации о созданной проверке"
    )
    
    return parser.parse_args()


def main() -> None:
    """
    Основная функция скрипта.
    """
    args = parse_arguments()
    
    logger.info("Запуск скрипта создания healthcheck")
    logger.info(f"Параметры: имя='{args.name}', slug='{args.slug}', теги='{args.tags}'")
    
    # ПРЕДУПРЕЖДЕНИЕ: скрипт создает реальные healthchecks в системе
    if not args.force:
        print("=" * 60)
        print("ПРЕДУПРЕЖДЕНИЕ: Этот скрипт создаст реальную проверку в healthchecks.io")
        print(f"Будет использован API токен: {args.token[:10]}...")
        print(f"URL API: {args.url}")
        print("=" * 60)
        
        confirm = input("Продолжить? (y/N): ").strip().lower()
        if confirm != 'y':
            logger.info("Создание проверки отменено пользователем")
            print("Отменено.")
            return
    
    try:
        result = create_check(
            url=args.url,
            api_token=args.token,
            name=args.name,
            slug=args.slug,
            tags=args.tags,
            timeout=args.timeout,
            grace=args.grace,
            unique=args.unique,
            channels=args.channels
        )
        
        if result:
            print("\n" + "=" * 60)
            print("Healthcheck успешно создан!")
            print(f"Имя: {result.get('name')}")
            print(f"Slug: {result.get('slug')}")
            print(f"Ping URL: {result.get('ping_url')}")
            print(f"Manage URL: {result.get('update_url')}")
            print(f"Теги: {result.get('tags')}")
            print(f"Таймаут: {result.get('timeout')} сек")
            print(f"Grace: {result.get('grace')} сек")
            print("=" * 60)
            
            # Сохраняем информацию в файл
            if args.output:
                output_file = args.output
            else:
                output_file = Path(f"healthcheck_{args.slug}.info")
                output_file = Path("logs") / f"healthcheck_{args.slug}.info"
            
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(f"# Healthcheck информация для {args.slug}\n\n")
                f.write(f"Имя: {result.get('name')}\n")
                f.write(f"Slug: {result.get('slug')}\n")
                f.write(f"Ping URL: {result.get('ping_url')}\n")
                f.write(f"Manage URL: {result.get('update_url')}\n")
                f.write(f"Теги: {result.get('tags')}\n")
                f.write(f"Таймаут: {result.get('timeout')} сек\n")
                f.write(f"Grace: {result.get('grace')} сек\n")
            
            logger.info(f"Информация сохранена в {output_file}")
            print(f"\nИнформация сохранена в: {output_file}")
            
        else:
            logger.error("Не удалось создать healthcheck")
            print("\nОшибка: не удалось создать healthcheck. Проверьте логи.")
            sys.exit(1)
            
    except Exception as e:
        logger.exception(f"Критическая ошибка: {e}")
        print(f"\nПроизошла ошибка: {e}. Проверьте логи для подробностей.")
        sys.exit(1)


if __name__ == "__main__":
    main()