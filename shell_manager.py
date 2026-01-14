#!/usr/bin/env python3
"""
Модуль для безопасного выполнения shell-команд.
Предоставляет функции для выполнения команд через subprocess с логированием.
"""

import subprocess
from logger_manager import log

def run_command(cmd, cwd=None, env=None, shell=True, check_stderr=True):
    """
    Выполняет команду и возвращает (success, output).

    Args:
        cmd (str): Команда для выполнения.
        cwd (str, optional): Рабочая директория.
        env (dict, optional): Переменные окружения.
        shell (bool): Использовать ли shell для выполнения.
        check_stderr (bool): Проверять ли stderr на наличие ошибок.

    Returns:
        tuple: (success: bool, output: str)
    """
    try:
        log.debug(f"Выполнение команды: {cmd}")
        result = subprocess.run(
            cmd,
            shell=shell,
            check=False,  # Не вызываем исключение при ненулевом коде возврата
            capture_output=True,
            text=True,
            cwd=cwd,
            env=env
        )
        # Проверяем код возврата
        if result.returncode != 0:
            error_msg = f"Команда завершилась с кодом {result.returncode}: {result.stderr}"
            log.error(error_msg)
            return False, result.stderr
        
        # Проверяем stderr на наличие ошибок, даже если код возврата 0
        if check_stderr and result.stderr:
            # Для некоторых команд (например, pg_dump) ошибки выводятся в stderr, но код возврата 0
            # Проверяем ключевые слова ошибок
            error_keywords = [
                'error', 'fatal', 'failed', 
                'неверный', 'ошибка', 'не удалось',
                'нет такого файла', 'command not found', 'not found',
                'отсутствует', 'не найден', 'cannot access',
                'permission denied', 'отказано в доступе'
            ]
            stderr_lower = result.stderr.lower()
            
            # Игнорируем определённые безобидные предупреждения
            ignore_patterns = [
                'could not change directory',
                # 'отказано в доступе' и 'permission denied' теперь являются ошибками, поэтому удаляем их из игнорируемых
            ]
            
            # Проверяем, содержит ли stderr игнорируемые предупреждения
            has_ignore_pattern = any(pattern in stderr_lower for pattern in ignore_patterns)
            
            # Проверяем наличие ключевых слов ошибок
            has_error_keyword = any(keyword in stderr_lower for keyword in error_keywords)
            
            if has_error_keyword and not has_ignore_pattern:
                error_msg = f"Обнаружена ошибка в stderr: {result.stderr}"
                log.error(error_msg)
                return False, result.stderr
            else:
                # Если stderr не содержит критических ошибок, это может быть предупреждение
                # Но не логируем игнорируемые предупреждения
                if not has_ignore_pattern:
                    log.warning(f"Команда выполнилась с предупреждением: {result.stderr}")
                else:
                    log.debug(f"Игнорируемое предупреждение в stderr: {result.stderr}")
        
        log.debug(f"Команда успешно выполнена: {result.stdout}")
        return True, result.stdout
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
        # Используем sudo с опцией -H для установки HOME в домашнюю директорию целевого пользователя
        # и -i для имитации логина (загружает окружение пользователя)
        full_cmd = f"sudo -u {sys_user} -i {cmd}"
        log.info(f"Выполнение от пользователя {sys_user}: {cmd}")
    else:
        full_cmd = cmd
        log.info(f"Выполнение от текущего пользователя: {cmd}")
    return run_command(full_cmd, cwd=cwd, env=env, check_stderr=True)

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
    return run_command(docker_cmd, cwd=cwd, env=env, check_stderr=True)

# Экспорт функций
__all__ = ['run_command', 'run_command_with_user', 'run_command_in_container']
