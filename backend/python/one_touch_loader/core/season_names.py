"""팀과 시즌 수집에서 연속된 두 연도인지 같은 기준으로 확인해요."""


def season_start_year(season_name: str) -> int:
    parts = season_name.split("/", 1)
    if len(parts) != 2:
        raise ValueError(f"Unsupported season name: {season_name!r}")

    try:
        start_year = int(parts[0])
        end_year = int(parts[1])
    except ValueError as exc:
        raise ValueError(f"Unsupported season name: {season_name!r}") from exc

    if end_year != start_year + 1:
        raise ValueError(f"Unsupported season name: {season_name!r}")
    return start_year
