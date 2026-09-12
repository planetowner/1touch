from __future__ import annotations

from typing import Dict, Optional, Tuple

from ..core.db import upsert_many
from ..core.sportmonks import SportmonksClient


SQL_UPSERT_COUNTRY = """
INSERT INTO countries (
  country_id,
  name,
  image_path
)
VALUES (%s,%s,%s)
ON DUPLICATE KEY UPDATE
  name       = VALUES(name),
  image_path = VALUES(image_path)
"""


def _require_int(value, field_name: str) -> int:
    if type(value) is not int:
        raise ValueError(f"Missing or invalid integer: {field_name}={value!r}")
    return value


def _require_string(value, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing or invalid string: {field_name}={value!r}")
    return value.strip()


def _optional_string(value, field_name: str) -> Optional[str]:
    if value is None:
        return None
    return _require_string(value, field_name)


def _normalize_country(country: Dict, index: int) -> Tuple[int, str, Optional[str]]:
    if not isinstance(country, dict):
        raise ValueError(f"countries[{index}] must be an object: {country!r}")
    return (
        _require_int(country.get("id"), f"countries[{index}].id"),
        _require_string(country.get("name"), f"countries[{index}].name"),
        _optional_string(
            country.get("image_path"),
            f"countries[{index}].image_path",
        ),
    )


def refresh_countries() -> Dict[str, int]:
    countries = list(SportmonksClient().iter_countries())
    if not countries:
        raise ValueError("Sportmonks returned an empty countries catalogue")

    rows = [
        _normalize_country(country, index)
        for index, country in enumerate(countries)
    ]

    upsert_many(SQL_UPSERT_COUNTRY, rows)
    result = {
        "countries": len(rows),
        "countries_without_image": sum(row[2] is None for row in rows),
    }
    print(
        f"[countries] upserted={result['countries']} "
        f"missing_images={result['countries_without_image']}"
    )
    return result
