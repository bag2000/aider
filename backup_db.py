#!/usr/bin/env python3
"""
Скрипт резервного копирования баз данных.
Поддерживает выполнение через sudo (локально) и через docker.
Использует конфигурацию из init.conf и отправляет ping-сигналы в Healthchecks.
"""

import sys
import os
import subprocess
import logging
import pathlib
import config_manager
from hc import ping_start, ping_success, ping_fail

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('backup_db.log')
    ]
)
logger = logging.getLogger(__name__)


def run_command(cmd, cwd=None, env=None):
    """
    Выполняет команду и возвращает (success, output).
    """
    try:
        logger.debug(f"Выполнение команды: {cmd}")
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            capture_output=True,
            text=True,
            cwd=cwd,
            env=env
        )
        logger.debug(f"Команда успешно выполнена: {result.stdout}")
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        error_msg = f"Ошибка выполнения команды: {e.stderr}"
        logger.error(error_msg)
        return False, error_msg
    except Exception as e:
        error_msg = f"Неожиданная ошибка: {e}"
        logger.error(error_msg)
        return False, error_msg


def construct_ping_url(ping_base, server_name, task_slug):
    """
    Формирует полный ping URL для задачи.
    """
    # Убираем возможные слэши в конце ping_base
    base = ping_base.rstrip('/')
    return f"{base}/{server_name}-{task_slug}"


def backup_task(task, general_settings):
    """
    Выполняет резервное копирование для одной задачи.
    """
    task_name = task.get('name', 'Без имени')
    task_slug = task.get('slug')
    db_type = task.get('db_type')
    container_name = task.get('container_name', '')
    bin_path = task.get('bin_path')
    args = task.get('args', '')
    db_user = task.get('db_user')
    sys_user = task.get('sys_user')
    output_file = task.get('output_file')
    backup_path = general_settings.get('backup_path')
    server_name = general_settings.get('server_name')
    ping_base = general_settings.get('ping_base', 'https://hc-ping.com')

    logger.info(f"Начинаем резервное копирование задачи: {task_name}")

    # Проверка обязательных параметров
    if not all([task_slug, db_type, bin_path, output_file, backup_path]):
        logger.error(f"Задача '{task_name}' пропущена: отсутствуют обязательные параметры.")
        return False

    # Формируем полный путь для сохранения резервной копии
    backup_dir = pathlib.Path(backup_path)
    backup_dir.mkdir(parents=True, exist_ok=True)
    output_path = backup_dir / output_file

    # Формируем ping URL
    ping_url = construct_ping_url(ping_base, server_name, task_slug)
    logger.info(f"Ping URL для задачи: {ping_url}")

    # Отправляем start ping
    try:
        ping_start(ping_url, data=f"Начало резервного копирования {task_name}")
        logger.info("Отправлен start ping.")
    except Exception as e:
        logger.warning(f"Не удалось отправить start ping: {e}")

    # Определяем команду резервного копирования в зависимости от типа БД
    if db_type == "postgres":
        # Для PostgreSQL используем pg_dumpall или pg_dump
        dump_cmd = f"{bin_path} {args}"
        if db_user:
            dump_cmd = f"PGUSER={db_user} {dump_cmd}"
    elif db_type == "mysql":
        # Для MySQL
        dump_cmd = f"{bin_path} {args}"
        if db_user:
            dump_cmd = f"mysql --user={db_user} --password='' {args}"
    else:
        logger.error(f"Неизвестный тип БД: {db_type}")
        # Отправляем fail ping
        try:
            ping_fail(ping_url, data=f"Неизвестный тип БД: {db_type}")
        except Exception as e:
            logger.warning(f"Не удалось отправить fail ping: {e}")
        return False

    # Если указан контейнер, выполняем команду внутри него
    if container_name:
        # Команда для выполнения внутри контейнера Docker
        docker_cmd = f"docker exec {container_name} sh -c '{dump_cmd}'"
        full_cmd = docker_cmd
        logger.info(f"Выполнение внутри контейнера: {container_name}")
    else:
        # Локальное выполнение через sudo, если указан sys_user
        if sys_user and sys_user != 'root':
            sudo_cmd = f"sudo -u {sys_user} {dump_cmd}"
        else:
            sudo_cmd = dump_cmd
        full_cmd = sudo_cmd
        logger.info(f"Локальное выполнение от пользователя: {sys_user or 'текущий'}")

    # Добавляем сжатие и сохранение в файл
    full_cmd = f"{full_cmd} | gzip -c > {output_path}"

    # Выполняем команду
    success, output = run_command(full_cmd)

    if success:
        # Проверяем, что файл создан и не пустой
        if output_path.exists() and output_path.stat().st_size > 0:
            logger.info(f"Резервная копия успешно создана: {output_path}")
            # Отправляем success ping
            try:
                ping_success(ping_url, data=f"Резервное копирование {task_name} завершено успешно")
                logger.info("Отправлен success ping.")
            except Exception as e:
                logger.warning(f"Не удалось отправить success ping: {e}")
            return True
        else:
            logger.error(f"Файл резервной копии не создан или пуст: {output_path}")
            # Отправляем fail ping
            try:
                ping_fail(ping_url, data=f"Файл резервной копии не создан или пуст: {output_path}")
            except Exception as e:
                logger.warning(f"Не удалось отправить fail ping: {e}")
            return False
    else:
        logger.error(f"Ошибка при выполнении резервного копирования: {output}")
        # Отправляем fail ping
        try:
            ping_fail(ping_url, data=f"Ошибка при выполнении резервного копирования: {output}")
        except Exception as e:
            logger.warning(f"Не удалось отправить fail ping: {e}")
        return False


def main():
    """
    Основная функция скрипта.
    """
    logger.info("Запуск скрипта резервного копирования БД.")

    # Загружаем конфигурацию
    try:
        config_manager.load_config()
        general_settings = config_manager.get_general_settings()
        tasks = config_manager.get_enabled_tasks()
    except SystemExit as e:
        logger.error(f"Ошибка загрузки конфигурации: {e}")
        sys.exit(1)

    if not tasks:
        logger.warning("Нет включённых задач для резервного копирования.")
        sys.exit(0)

    logger.info(f"Найдено {len(tasks)} включённых задач.")

    # Выполняем резервное копирование для каждой задачи
    results = []
    for task in tasks:
        success = backup_task(task, general_settings)
        results.append((task.get('name'), success))

    # Итоговый отчёт
    logger.info("=" * 50)
    logger.info("ИТОГ ВЫПОЛНЕНИЯ:")
    for task_name, success in results:
        status = "УСПЕХ" if success else "ОШИБКА"
        logger.info(f"  {task_name}: {status}")

    # Если хотя бы одна задача завершилась неудачно, завершаем с кодом ошибки
    if any(not success for _, success in results):
        logger.error("Некоторые задачи завершились с ошибкой.")
        sys.exit(1)
    else:
        logger.info("Все задачи выполнены успешно.")
        sys.exit(0)


if __name__ == "__main__":
    main()
