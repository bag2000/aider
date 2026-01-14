#!/usr/bin/env python3
"""
Основной скрипт для управления резервным копированием БД.
Поддерживает запуск резервного копирования и инициализацию чеков Healthchecks.
"""

import sys
import argparse
import subprocess
from pathlib import Path

# Добавляем путь к модулям проекта
sys.path.insert(0, str(Path(__file__).parent))

from logger_manager import log


def run_backup():
    """
    Запускает процесс резервного копирования БД.
    """
    log.info("Запуск процесса резервного копирования БД.")
    try:
        # Импортируем здесь, чтобы избежать циклических зависимостей
        import backup_db
        backup_db.main()
    except ImportError as e:
        log.error(f"Не удалось импортировать модуль backup_db: {e}")
        sys.exit(1)
    except Exception as e:
        log.error(f"Ошибка при выполнении резервного копирования: {e}")
        sys.exit(1)


def run_init_checks(token, base_url):
    """
    Запускает инициализацию чеков Healthchecks.
    """
    log.info(f"Запуск инициализации чеков Healthchecks с токеном {token[:8]}...")
    try:
        import init_checks
        init_checks.init_checks(token, base_url)
    except ImportError as e:
        log.error(f"Не удалось импортировать модуль init_checks: {e}")
        sys.exit(1)
    except Exception as e:
        log.error(f"Ошибка при инициализации чеков: {e}")
        sys.exit(1)


def main():
    """
    Основная функция скрипта.
    """
    parser = argparse.ArgumentParser(
        description="Управление резервным копированием БД и Healthchecks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры использования:
  %(prog)s backup               # Запустить резервное копирование
  %(prog)s init-checks <TOKEN>  # Инициализировать чеки Healthchecks
  %(prog)s init-checks <TOKEN> --base-url https://hc.example.com/api/v1/checks/
        """
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Доступные команды")

    # Команда backup
    backup_parser = subparsers.add_parser("backup", help="Запустить резервное копирование БД")
    backup_parser.set_defaults(func=lambda args: run_backup())

    # Команда init-checks
    init_parser = subparsers.add_parser("init-checks", help="Инициализировать чеки Healthchecks")
    init_parser.add_argument("token", help="API токен Healthchecks")
    init_parser.add_argument("--base-url", 
                           default="https://healthchecks.io/api/v1/checks/",
                           help="Базовый URL API Healthchecks (по умолчанию: %(default)s)")
    init_parser.set_defaults(func=lambda args: run_init_checks(args.token, args.base_url))

    # Парсинг аргументов
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)
    
    args = parser.parse_args()
    
    # Выполняем выбранную команду
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
