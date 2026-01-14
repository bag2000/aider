#!/usr/bin/env python3
"""
Менеджер логирования на основе Loguru.
Обеспечивает ротацию логов, форматирование и централизованную конфигурацию.
"""

import sys
from pathlib import Path
from loguru import logger

# Директория для логов
LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)

# Основной файл логов
LOG_FILE = LOG_DIR / "backup_db.log"

# Конфигурация формата
LOG_FORMAT = (
    "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
    "<level>{level: <8}</level> | "
    "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> | "
    "<level>{message}</level>"
)

def setup_logger(level="INFO", rotation="10 MB", retention="30 days", compression="zip"):
    """
    Настройка глобального логгера Loguru.

    Args:
        level (str): Уровень логирования (DEBUG, INFO, WARNING, ERROR).
        rotation (str): Условие ротации (например, "10 MB", "1 day").
        retention (str): Время хранения старых логов (например, "30 days").
        compression (str): Сжатие архивов ("zip", "gz", None).
    """
    # Удаляем стандартный обработчик Loguru
    logger.remove()

    # Добавляем вывод в консоль (stderr)
    logger.add(
        sys.stderr,
        format=LOG_FORMAT,
        level=level,
        colorize=True,
        backtrace=True,
        diagnose=True,
    )

    # Добавляем вывод в файл с ротацией
    logger.add(
        str(LOG_FILE),
        format=LOG_FORMAT,
        level=level,
        rotation=rotation,
        retention=retention,
        compression=compression,
        backtrace=True,
        diagnose=True,
        enqueue=True,  # Асинхронная запись для избежания блокировок
    )

    return logger

# Инициализация логгера по умолчанию
log = setup_logger()

# Экспорт для удобства
__all__ = ["log", "setup_logger", "logger"]
