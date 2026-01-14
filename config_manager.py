#!/usr/bin/env python3
"""
Модуль для управления конфигурацией скрипта резервного копирования БД.
Чтение настроек из YAML-файла init.conf.
"""

import sys
import yaml

# Глобальная переменная для кэширования загруженной конфигурации
_CONFIG = None

def load_config(config_path="init.conf"):
    """
    Загружает конфигурацию из YAML-файла и кэширует её в глобальной переменной.
    
    Args:
        config_path (str): Путь к файлу конфигурации.
    
    Raises:
        SystemExit: При ошибках чтения файла или парсинга YAML.
    """
    global _CONFIG
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            _CONFIG = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Ошибка: Файл конфигурации '{config_path}' не найден.", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Ошибка парсинга YAML в файле '{config_path}': {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Неожиданная ошибка при чтении '{config_path}': {e}", file=sys.stderr)
        sys.exit(1)

def get_general_settings():
    """
    Возвращает словарь с общими настройками из секции general.
    
    Returns:
        dict: Содержит ключи 'backup_path', 'server_name', 'base_url', 'ping_base'.
    
    Raises:
        SystemExit: Если конфигурация не загружена или отсутствует секция general.
    """
    if _CONFIG is None:
        load_config()
    
    general = _CONFIG.get('general')
    if general is None:
        print("Ошибка: В конфигурации отсутствует секция 'general'.", file=sys.stderr)
        sys.exit(1)
    
    # Возвращаем копию, чтобы избежать случайных изменений
    return {
        'backup_path': general.get('backup_path'),
        'server_name': general.get('server_name'),
        'base_url': general.get('base_url', 'https://healthchecks.io/api/v1/checks/'),
        'ping_base': general.get('ping_base', 'https://hc-ping.com')
    }

def get_enabled_db_backup_tasks():
    """
    Возвращает список задач резервного копирования БД, у которых enable: true.
    
    Returns:
        list: Список словарей с настройками задач.
    
    Raises:
        SystemExit: Если конфигурация не загружена или отсутствует секция tasks_backup_db.
    """
    if _CONFIG is None:
        load_config()
    
    tasks = _CONFIG.get('tasks_backup_db')
    if tasks is None:
        print("Ошибка: В конфигурации отсутствует секция 'tasks_backup_db'.", file=sys.stderr)
        sys.exit(1)
    
    # Фильтруем только включённые задачи
    enabled_tasks = [task for task in tasks if task.get('enable') is True]
    return enabled_tasks

def get_enabled_tasks():
    """
    Возвращает список задач из секции tasks, у которых enable: true.
    
    Returns:
        list: Список словарей с настройками задач.
    
    Raises:
        SystemExit: Если конфигурация не загружена или отсутствует секция tasks.
    """
    if _CONFIG is None:
        load_config()
    
    tasks = _CONFIG.get('tasks')
    if tasks is None:
        print("Ошибка: В конфигурации отсутствует секция 'tasks'.", file=sys.stderr)
        sys.exit(1)
    
    # Фильтруем только включённые задачи
    enabled_tasks = [task for task in tasks if task.get('enable') is True]
    return enabled_tasks

# Если модуль запущен напрямую, демонстрируем его работу
if __name__ == "__main__":
    print("Тестирование модуля config_manager.py")
    print("=" * 40)
    
    # Загружаем конфигурацию
    load_config()
    print("Конфигурация загружена успешно.")
    
    # Получаем общие настройки
    general = get_general_settings()
    print(f"Общие настройки: {general}")
    
    # Получаем включённые задачи
    enabled_tasks = get_enabled_db_backup_tasks()
    print(f"Найдено включённых задач: {len(enabled_tasks)}")
    for i, task in enumerate(enabled_tasks, 1):
        print(f"  {i}. {task.get('name')} (slug: {task.get('slug')})")
