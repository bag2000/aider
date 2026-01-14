import argparse
import sys

from hc import add_check
import config_manager


def parse_args():
    parser = argparse.ArgumentParser(
        description="Создание чеков Healthchecks для включённых задач резервного копирования."
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

        # Загружаем конфигурацию
        config_manager.load_config()
        general = config_manager.get_general_settings()
        server_name = general.get('server_name')
        if not server_name:
            print("Ошибка: server_name не указан в секции general", file=sys.stderr)
            sys.exit(1)

        # Определяем base_url: приоритет у аргумента командной строки, затем конфигурация
        base_url = args.base_url if args.base_url != "https://healthchecks.io/api/v1/checks/" else general.get('base_url')
        ping_base = general.get('ping_base', 'https://hc-ping.com')
        print(f"Используемый base_url: {base_url}")
        print(f"Используемый ping_base: {ping_base}")

        # Получаем включённые задачи
        try:
            tasks = config_manager.get_enabled_tasks()
        except SystemExit:
            # Если секция tasks отсутствует, выходим
            print("Ошибка: не удалось получить список задач", file=sys.stderr)
            sys.exit(1)

        if not tasks:
            print("Нет включённых задач для создания чеков.")
            sys.exit(0)

        print(f"Создание чеков для сервера: {server_name}")
        print(f"Найдено включённых задач: {len(tasks)}")

        for task in tasks:
            task_slug = task.get('slug')
            if not task_slug:
                print(f"Предупреждение: у задачи '{task.get('name')}' отсутствует slug, пропускаем.")
                continue

            full_slug = f"{server_name}_{task_slug}"
            print(f"  Создание чека для задачи: {task.get('name')} (slug: {full_slug})")

            try:
                result = add_check(
                    token=args.token,
                    name=server_name,
                    tags="prod www",
                    timeout=3600,
                    grace=60,
                    channels="",
                    base_url=base_url,
                    slug=full_slug,
                )
                print(f"    Результат: {result['status']}")
                if 'check' in result and 'ping_url' in result['check']:
                    print(f"    Ping URL: {result['check']['ping_url']}")
            except Exception as e:
                print(f"    Ошибка при создании чека: {e}", file=sys.stderr)

        print("Инициализация завершена.")
        sys.exit(0)

    print("Основная логика... (используйте --init для создания чеков)")


if __name__ == "__main__":
    main()
