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
) -> dict:
    """
    Create Healthchecks check if it does not exist.
    """

    headers = {
        "X-Api-Key": token,
        "Content-Type": "application/json",
    }

    payload = {
        "name": name,
        "slug": name,
        "tags": tags,
        "timeout": timeout,
        "grace": grace,
        "channels": channels,
    }

    with requests.Session() as session:
        session.headers.update(headers)

        # check existence
        response = session.get(base_url, params={"slug": name})
        response.raise_for_status()
        checks = response.json().get("checks", [])

        if checks:
            return {
                "status": "exists",
                "check": checks[0],
            }

        # create check
        response = session.post(base_url, json=payload)
        response.raise_for_status()

        return {
            "status": "created",
            "check": response.json(),
        }
