#!/usr/bin/env python3
"""
Основной скрипт для управления резервным копированием БД.
Инициализация чеков вынесена в отдельный модуль init_checks.py.
"""

def main():
    print("Основная логика резервного копирования БД.")
    print("Для инициализации чеков Healthchecks используйте:")
    print("  python init_checks.py <TOKEN>")
    print("или")
    print("  python init_checks.py <TOKEN> --base-url <URL>")


if __name__ == "__main__":
    main()
