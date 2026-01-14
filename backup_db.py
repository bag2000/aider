#!/usr/bin/env python3
"""
Скрипт резервного копирования баз данных.
Поддерживает выполнение через sudo (локально) и через docker.
Использует конфигурацию из init.conf и отправляет ping-сигналы в Healthchecks.
"""

import sys
import pathlib
import config_manager
from hc import ping_start, ping_success, ping_fail
from logger_manager import log
from shell_manager import run_command_with_user, run_command_in_container, run_command


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

    log.info(f"Начинаем резервное копирование задачи: {task_name}")

    # Проверка обязательных параметров
    # Для задач без output_file (например, restic check) не требуем output_file
    required_params = [task_slug, db_type, bin_path, backup_path]
    if output_file:
        required_params.append(output_file)
    if not all(required_params):
        log.error(f"Задача '{task_name}' пропущена: отсутствуют обязательные параметры.")
        return False

    # Формируем ping URL
    ping_url = construct_ping_url(ping_base, server_name, task_slug)
    log.info(f"Ping URL для задачи: {ping_url}")

    # Отправляем start ping
    try:
        ping_start(ping_url, data=f"Начало резервного копирования {task_name}")
        log.info("Отправлен start ping.")
    except Exception as e:
        log.warning(f"Не удалось отправить start ping: {e}")

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
    elif not db_type or db_type == "restic":
        # Для задач, не связанных с БД (например, restic check)
        # Используем bin_path и args напрямую
        dump_cmd = f"{bin_path} {args}"
    else:
        log.error(f"Неизвестный тип БД: {db_type}")
        # Отправляем fail ping
        try:
            ping_fail(ping_url, data=f"Неизвестный тип БД: {db_type}")
        except Exception as e:
            log.warning(f"Не удалось отправить fail ping: {e}")
        return False

    # Формируем команду для выполнения
    # Если указан контейнер, выполняем команду внутри него
    if container_name:
        # Команда для выполнения внутри контейнера Docker
        # Если output_file пустой, не перенаправляем вывод в файл
        if output_file:
            # Формируем полный путь для сохранения резервной копии
            backup_dir = pathlib.Path(backup_path)
            backup_dir.mkdir(parents=True, exist_ok=True)
            output_path = backup_dir / output_file
            full_cmd = f"{dump_cmd} | gzip -c > {output_path}"
        else:
            full_cmd = dump_cmd
            output_path = None
        success, output = run_command_in_container(container_name, full_cmd)
    else:
        # Локальное выполнение через sudo, если указан sys_user
        # Если output_file пустой, не перенаправляем вывод в файл
        if output_file:
            backup_dir = pathlib.Path(backup_path)
            backup_dir.mkdir(parents=True, exist_ok=True)
            output_path = backup_dir / output_file
            full_cmd = f"{dump_cmd} | gzip -c > {output_path}"
        else:
            full_cmd = dump_cmd
            output_path = None
        success, output = run_command_with_user(full_cmd, sys_user)

    if success:
        # Если output_file указан, проверяем, что файл создан и не пустой
        if output_file:
            if output_path.exists() and output_path.stat().st_size > 0:
                log.info(f"Резервная копия успешно создана: {output_path}")
                # Отправляем success ping
                try:
                    ping_success(ping_url, data=f"Резервное копирование {task_name} завершено успешно")
                    log.info("Отправлен success ping.")
                except Exception as e:
                    log.warning(f"Не удалось отправить success ping: {e}")
                return True
            else:
                log.error(f"Файл резервной копии не создан или пуст: {output_path}")
                # Отправляем fail ping
                try:
                    ping_fail(ping_url, data=f"Файл резервной копии не создан или пуст: {output_path}")
                except Exception as e:
                    log.warning(f"Не удалось отправить fail ping: {e}")
                return False
        else:
            # Для задач без output_file считаем успехом сам факт успешного выполнения команды
            log.info(f"Команда выполнена успешно: {dump_cmd}")
            try:
                ping_success(ping_url, data=f"Задача {task_name} завершена успешно")
                log.info("Отправлен success ping.")
            except Exception as e:
                log.warning(f"Не удалось отправить success ping: {e}")
            return True
    else:
        log.error(f"Ошибка при выполнении резервного копирования: {output}")
        # Отправляем fail ping
        try:
            ping_fail(ping_url, data=f"Ошибка при выполнении резервного копирования: {output}")
        except Exception as e:
            log.warning(f"Не удалось отправить fail ping: {e}")
        return False


def main():
    """
    Основная функция скрипта.
    """
    log.info("Запуск скрипта резервного копирования БД.")

    # Загружаем конфигурацию
    try:
        config_manager.load_config()
        general_settings = config_manager.get_general_settings()
        tasks = config_manager.get_enabled_tasks()
    except SystemExit as e:
        log.error(f"Ошибка загрузки конфигурации: {e}")
        sys.exit(1)

    if not tasks:
        log.warning("Нет включённых задач для резервного копирования.")
        sys.exit(0)

    log.info(f"Найдено {len(tasks)} включённых задач.")

    # Выполняем резервное копирование для каждой задачи
    results = []
    for task in tasks:
        success = backup_task(task, general_settings)
        results.append((task.get('name'), success))

    # Итоговый отчёт
    log.info("=" * 50)
    log.info("ИТОГ ВЫПОЛНЕНИЯ:")
    for task_name, success in results:
        status = "УСПЕХ" if success else "ОШИБКА"
        log.info(f"  {task_name}: {status}")

    # Если хотя бы одна задача завершилась неудачно, завершаем с кодом ошибки
    if any(not success for _, success in results):
        log.error("Некоторые задачи завершились с ошибкой.")
        sys.exit(1)
    else:
        log.info("Все задачи выполнены успешно.")
        sys.exit(0)


if __name__ == "__main__":
    main()
