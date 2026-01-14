#!/usr/bin/env python3
"""
Основной скрипт для запуска резервного копирования БД.
Запускает процесс резервного копирования без параметров.
"""

import sys
from pathlib import Path

# Добавляем путь к модулям проекта
sys.path.insert(0, str(Path(__file__).parent))

from logger_manager import log


def main():
    """
    Основная функция скрипта.
    """
    log.info("Запуск процесса резервного копирования БД.")
    try:
        import backup_db
        backup_db.main()
    except ImportError as e:
        log.error(f"Не удалось импортировать модуль backup_db: {e}")
        sys.exit(1)
    except Exception as e:
        log.error(f"Ошибка при выполнении резервного копирования: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
