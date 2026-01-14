import argparse
import sys

from hc import add_check


def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument("--init", action="store_true")
    parser.add_argument("token", nargs="?")

    return parser.parse_args()


def main():
    args = parse_args()

    if args.init:
        if not args.token:
            print("TOKEN is required with --init", file=sys.stderr)
            sys.exit(1)

        result = add_check(
            token=args.token,
            name="backups",
            tags="prod www",
            timeout=3600,
            grace=60,
            channels="319329f7-0060-4219-8fd8-6f8a1d1f2258,abbddf53-8bf5-47bf-bc85-e79d99d08c70",
        )

        print(f"HC init result: {result['status']}")

    print("Main logic running...")


if __name__ == "__main__":
    main()
