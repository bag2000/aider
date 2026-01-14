#!/usr/bin/env python3
"""
Модуль для безопасного выполнения shell-команд.
Предоставляет функции для выполнения команд через subprocess с логированием.
"""

import subprocess
from logger_manager import log

def run_command(cmd, cwd=None, env=None, shell=True):
    """
    Выполняет команду и возвращает (success, output).

    Args:
        cmd (str): Команда для выполнения.
        cwd (str, optional): Рабочая директория.
        env (dict, optional): Переменные окружения.
        shell (bool): Использовать ли shell для выполнения.

    Returns:
        tuple: (success: bool, output: str)
    """
    try:
        log.debug(f"Выполнение команды: {cmd}")
        result = subprocess.run(
            cmd,
            shell=shell,
            check=True,
            capture_output=True,
            text=True,
            cwd=cwd,
            env=env
        )
        log.debug(f"Команда успешно выполнена: {result.stdout}")
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        error_msg = f"Ошибка выполнения команды: {e.stderr}"
        log.error(error_msg)
        return False, error_msg
    except Exception as e:
        error_msg = f"Неожиданная ошибка: {e}"
        log.error(error_msg)
        return False, error_msg

def run_command_with_user(cmd, sys_user=None, cwd=None, env=None):
    """
    Выполняет команду от имени указанного пользователя через sudo.

    Args:
        cmd (str): Команда для выполнения.
        sys_user (str, optional): Пользователь для sudo -u. Если None или 'root', sudo не используется.
        cwd (str, optional): Рабочая директория.
        env (dict, optional): Переменные окружения.

    Returns:
        tuple: (success: bool, output: str)
    """
    if sys_user and sys_user != 'root':
        full_cmd = f"sudo -u {sys_user} {cmd}"
        log.info(f"Выполнение от пользователя {sys_user}: {cmd}")
    else:
        full_cmd = cmd
        log.info(f"Выполнение от текущего пользователя: {cmd}")
    return run_command(full_cmd, cwd=cwd, env=env)

def run_command_in_container(container_name, cmd, cwd=None, env=None):
    """
    Выполняет команду внутри контейнера Docker.

    Args:
        container_name (str): Имя контейнера.
        cmd (str): Команда для выполнения внутри контейнера.
        cwd (str, optional): Рабочая директория (внутри контейнера).
        env (dict, optional): Переменные окружения.

    Returns:
        tuple: (success: bool, output: str)
    """
    docker_cmd = f"docker exec {container_name} sh -c '{cmd}'"
    log.info(f"Выполнение внутри контейнера {container_name}: {cmd}")
    return run_command(docker_cmd, cwd=cwd, env=env)

# Экспорт функций
__all__ = ['run_command', 'run_command_with_user', 'run_command_in_container']
