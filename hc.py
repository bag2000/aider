import requests


def add_check(
    *,
    token: str,
    name: str,
    tags: str,
    timeout: int,
    grace: int,
    channels: str,
    base_url: str,
    slug: str = None,
) -> dict:
    """
    Create Healthchecks check if it does not exist.
    """

    headers = {
        "X-Api-Key": token,
        "Content-Type": "application/json",
    }

    # Если slug не указан, используем name
    effective_slug = slug if slug is not None else name

    payload = {
        "name": name,
        "slug": effective_slug,
        "tags": tags,
        "timeout": timeout,
        "grace": grace,
        "channels": channels,
    }

    with requests.Session() as session:
        session.headers.update(headers)

        # check existence по slug
        response = session.get(base_url, params={"slug": effective_slug}, timeout=10)
        response.raise_for_status()
        checks = response.json().get("checks", [])

        if checks:
            return {
                "status": "exists",
                "check": checks[0],
            }

        # create check
        response = session.post(base_url, json=payload, timeout=10)
        response.raise_for_status()

        return {
            "status": "created",
            "check": response.json(),
        }


def ping_start(ping_url: str, data: str = None) -> None:
    """
    Send a start signal to Healthchecks.
    """
    url = f"{ping_url}/start"
    _send_ping(url, data)


def ping_success(ping_url: str, data: str = None) -> None:
    """
    Send a success signal to Healthchecks.
    """
    _send_ping(ping_url, data)


def ping_fail(ping_url: str, data: str = None) -> None:
    """
    Send a fail signal to Healthchecks.
    """
    url = f"{ping_url}/fail"
    _send_ping(url, data)


def _send_ping(url: str, data: str = None) -> None:
    """
    Internal helper to send a POST request to a Healthchecks ping endpoint.
    """
    with requests.Session() as session:
        if data is not None:
            response = session.post(url, data=data.encode("utf-8"), timeout=10)
        else:
            response = session.post(url, timeout=10)
        response.raise_for_status()
