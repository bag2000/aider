#!/usr/bin/env python3
"""
Основной скрипт для управления резервным копированием БД.
Поддерживает инициализацию чеков Healthchecks через отдельный модуль.
"""

import argparse
import sys

import init_checks


def parse_args():
    parser = argparse.ArgumentParser(
        description="Управление резервным копированием БД и Healthchecks."
    )
    parser.add_argument("--init", action="store_true",
                        help="Создать чеки для всех включённых задач в init.conf")
    parser.add_argument("token", nargs="?",
                        help="API токен Healthchecks (обязателен с --init)")
    parser.add_argument("--base-url", default="https://healthchecks.io/api/v1/checks/",
                        help="Базовый URL API Healthchecks (по умолчанию: %(default)s)")
    return parser.parse_args()


def main():
    args = parse_args()

    if args.init:
        if not args.token:
            print("Ошибка: TOKEN обязателен при использовании --init", file=sys.stderr)
            sys.exit(1)
        # Делегируем инициализацию отдельному модулю
        init_checks.init_checks(args.token, args.base_url)
        sys.exit(0)

    print("Основная логика... (используйте --init для создания чеков)")


if __name__ == "__main__":
    main()
