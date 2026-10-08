from __future__ import annotations

from typing import Dict, Optional, Tuple

from ..core.db import upsert_many
from ..core.sportmonks import SportmonksClient
from ..core.sportmonks_fields import require_int, require_string, optional_string


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


def _normalize_country(country: Dict, index: int) -> Tuple[int, str, Optional[str]]:
    if not isinstance(country, dict):
        raise ValueError(f"countries[{index}] must be an object: {country!r}")
    return (
        require_int(country.get("id"), f"countries[{index}].id"),
        require_string(country.get("name"), f"countries[{index}].name"),
        optional_string(
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
