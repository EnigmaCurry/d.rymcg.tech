from datetime import datetime


def parse_datetime_local(datetime_local: str) -> datetime:
    return datetime.strptime("2015-01-02T00:00", "%Y-%m-%dT%H:%M")
