from __future__ import annotations

import os
import time
import random
from datetime import date
from typing import Dict, Iterable, List, Optional
from urllib.parse import parse_qs, urlparse

import requests
from dotenv import load_dotenv


load_dotenv()


class SportmonksClient:
    """
    Sportmonks Football API v3 client.

    Confirmed response contract:
      - single-resource endpoints return top-level {"data": dict, ...}
      - list endpoints return top-level {"data": list, ...}
      - paginated endpoints use top-level "pagination.has_more"
    """

    def __init__(
        self,
        api_base: Optional[str] = None,
        token: Optional[str] = None,
        timeout: int = 60,
        request_interval_sec: float = 1.5,
    ):
        self.base = (
            api_base
            or os.getenv("SPORTMONKS_BASE_URL")
            or "https://api.sportmonks.com/v3/football"
        ).rstrip("/")

        self.token = token or os.getenv("SPORTMONKS_API_TOKEN")

        if not self.token:
            raise RuntimeError("SPORTMONKS_API_TOKEN is not set")

        self.timeout = timeout
        self.request_interval_sec = float(
            os.getenv("SPORTMONKS_REQUEST_INTERVAL_SEC", str(request_interval_sec))
        )
        self._last_request_at = 0.0
        self._session = requests.Session()

    def _wait_before_request(self) -> None:
        elapsed = time.monotonic() - self._last_request_at

        if elapsed < self.request_interval_sec:
            time.sleep(self.request_interval_sec - elapsed)

    def _get(
        self,
        path: str,
        params: Optional[Dict] = None,
        max_retries: int = 10,
    ) -> Dict:
        url = f"{self.base}/{path.lstrip('/')}"
        headers = {
            "Accept": "application/json",
            "Authorization": self.token,
        }

        backoff = 3.0
        last_exc = None
        last_status_code = None
        last_response_text = None

        for attempt in range(1, max_retries + 1):
            try:
                self._wait_before_request()

                resp = self._session.get(
                    url,
                    headers=headers,
                    params=params if params is not None else {},
                    timeout=self.timeout,
                )

                self._last_request_at = time.monotonic()
                last_status_code = resp.status_code
                last_response_text = resp.text[:500]

            except (requests.Timeout, requests.ConnectionError) as exc:
                self._last_request_at = time.monotonic()
                last_exc = exc

                if attempt < max_retries:
                    sleep_sec = min(backoff, 120.0)
                    print(
                        f"[sportmonks] network retry "
                        f"attempt={attempt}/{max_retries} "
                        f"path={path} sleep={sleep_sec:.1f}s error={exc}"
                    )
                    time.sleep(sleep_sec + random.uniform(0, 0.5))
                    backoff = min(backoff * 2, 120.0)
                    continue

                raise

            if resp.status_code == 429:
                retry_after = resp.headers.get("Retry-After")

                if retry_after is None:
                    sleep_sec = min(backoff, 120.0)
                else:
                    try:
                        sleep_sec = min(float(retry_after), 120.0)
                    except ValueError:
                        sleep_sec = min(backoff, 120.0)

                print(
                    f"[sportmonks] rate limited "
                    f"attempt={attempt}/{max_retries} "
                    f"path={path} sleep={sleep_sec:.1f}s"
                )

                if attempt < max_retries:
                    time.sleep(sleep_sec + random.uniform(0, 0.5))
                    backoff = min(backoff * 2, 120.0)
                    continue

                raise requests.HTTPError(
                    f"Sportmonks rate limit did not recover after {max_retries} retries. "
                    f"url={url} params={params!r} "
                    f"last_status={last_status_code} "
                    f"last_response={last_response_text!r}"
                )

            try:
                resp.raise_for_status()
            except requests.HTTPError as exc:
                last_exc = exc

                if 500 <= resp.status_code < 600 and attempt < max_retries:
                    sleep_sec = min(backoff, 120.0)
                    print(
                        f"[sportmonks] server retry "
                        f"attempt={attempt}/{max_retries} "
                        f"path={path} status={resp.status_code} "
                        f"sleep={sleep_sec:.1f}s"
                    )
                    time.sleep(sleep_sec + random.uniform(0, 0.5))
                    backoff = min(backoff * 2, 120.0)
                    continue

                raise

            payload = resp.json()

            if not isinstance(payload, dict):
                raise ValueError(
                    f"Sportmonks response must be a JSON object. "
                    f"path={path!r}, type={type(payload).__name__}"
                )

            return payload

        if last_exc is not None:
            raise last_exc

        raise requests.HTTPError(
            f"GET failed after {max_retries} retries: {url} "
            f"params={params!r} "
            f"last_status={last_status_code} "
            f"last_response={last_response_text!r}"
        )

    # ------------------------------------------------------------------
    # Response contract helpers
    # ------------------------------------------------------------------

    def _require_data_dict(self, response: Dict, endpoint_name: str) -> Dict:
        if "data" not in response:
            raise ValueError(f"{endpoint_name}: response missing top-level 'data'.")

        data = response["data"]

        if not isinstance(data, dict):
            raise ValueError(
                f"{endpoint_name}: expected top-level data dict, "
                f"got {type(data).__name__}: {data!r}"
            )

        return data

    def _require_data_list(self, response: Dict, endpoint_name: str) -> List[Dict]:
        if "data" not in response:
            raise ValueError(f"{endpoint_name}: response missing top-level 'data'.")

        data = response["data"]

        if not isinstance(data, list):
            raise ValueError(
                f"{endpoint_name}: expected top-level data list, "
                f"got {type(data).__name__}: {data!r}"
            )

        for index, item in enumerate(data):
            if not isinstance(item, dict):
                raise ValueError(
                    f"{endpoint_name}: data[{index}] must be dict, "
                    f"got {type(item).__name__}: {item!r}"
                )

        return data

    def _require_pagination(self, response: Dict, endpoint_name: str) -> Dict:
        if "pagination" not in response:
            raise ValueError(f"{endpoint_name}: response missing top-level 'pagination'.")

        pagination = response["pagination"]

        if not isinstance(pagination, dict):
            raise ValueError(
                f"{endpoint_name}: pagination must be dict, "
                f"got {type(pagination).__name__}: {pagination!r}"
            )

        if "has_more" not in pagination:
            raise ValueError(f"{endpoint_name}: pagination missing 'has_more'.")

        if type(pagination["has_more"]) is not bool:
            raise ValueError(
                f"{endpoint_name}: pagination.has_more must be bool, "
                f"got {pagination['has_more']!r}"
            )

        return pagination

    def _params_from_pagination_url(
        self,
        pagination_url: str,
        endpoint_name: str,
        pagination_field: str,
    ) -> Dict:
        if not isinstance(pagination_url, str) or not pagination_url.strip():
            raise ValueError(
                f"{endpoint_name}: pagination.has_more=true but "
                f"{pagination_field} is missing."
            )

        parsed = urlparse(pagination_url)
        query = parse_qs(parsed.query)

        if not query:
            raise ValueError(
                f"{endpoint_name}: {pagination_field} URL has no query params. "
                f"{pagination_field}={pagination_url!r}"
            )

        params: Dict = {}

        for key, values in query.items():
            if len(values) != 1:
                raise ValueError(
                    f"{endpoint_name}: {pagination_field} query param must have "
                    f"exactly one value. key={key!r}, values={values!r}"
                )

            params[key] = values[0]

        return params

    def _iter_paginated_data(
        self,
        path: str,
        *,
        endpoint_name: str,
        params: Optional[Dict] = None,
    ):
        request_params = dict(params or {})

        while True:
            response = self._get(path, params=request_params)

            data = self._require_data_list(response, endpoint_name)

            for item in data:
                yield item

            if "pagination" not in response:
                if len(data) == 0:
                    break

                raise ValueError(
                    f"{endpoint_name}: response missing top-level 'pagination' "
                    f"on a non-empty page. "
                    f"path={path!r} params={request_params!r} "
                    f"top_level_keys={list(response.keys())!r} "
                    f"data_len={len(data)}"
                )

            pagination = self._require_pagination(response, endpoint_name)

            if not pagination["has_more"]:
                break

            # Verified live: when has_more=true, pagination.next_cursor is
            # always a non-empty URL string (the legacy next_page is also
            # present but redundant). Cursor-only — _params_from_pagination_url
            # raises if next_cursor is unexpectedly missing or malformed.
            request_params = self._params_from_pagination_url(
                pagination["next_cursor"],
                endpoint_name,
                "next_cursor",
            )

    # ------------------------------------------------------------------
    # Leagues / Seasons
    # ------------------------------------------------------------------

    def get_league(self, league_id: int) -> Dict:
        response = self._get(f"leagues/{league_id}")
        return self._require_data_dict(response, "get_league")

    def get_league_with_seasons(self, league_id: int) -> Dict:
        response = self._get(
            f"leagues/{league_id}",
            params={"include": "seasons"},
        )
        return self._require_data_dict(response, "get_league_with_seasons")

    # ------------------------------------------------------------------
    # Teams
    # ------------------------------------------------------------------

    def iter_teams_by_season(
        self,
        season_id: int,
        per_page: int = 50,
    ) -> Iterable[Dict]:
        response = self._get(
            f"teams/seasons/{season_id}",
            params={
                "per_page": per_page,
                "page": 1,
            },
        )

        items = self._require_data_list(response, "iter_teams_by_season")

        for team in items:
            yield team

        if "pagination" in response:
            pagination = self._require_pagination(response, "iter_teams_by_season")

            if pagination["has_more"]:
                page = 2

                while True:
                    page_response = self._get(
                        f"teams/seasons/{season_id}",
                        params={
                            "per_page": per_page,
                            "page": page,
                        },
                    )

                    page_items = self._require_data_list(
                        page_response,
                        "iter_teams_by_season",
                    )
                    page_pagination = self._require_pagination(
                        page_response,
                        "iter_teams_by_season",
                    )

                    for team in page_items:
                        yield team

                    if not page_pagination["has_more"]:
                        break

                    page += 1

    def get_team(self, team_id: int) -> Dict:
        response = self._get(f"teams/{team_id}")
        return self._require_data_dict(response, "get_team")

    def get_team_with_sidelined(self, team_id: int) -> Dict:
        """
        Confirmed include:
          sidelined.player;sidelined.type
        """
        response = self._get(
            f"teams/{team_id}",
            params={"include": "sidelined.player;sidelined.type"},
        )
        return self._require_data_dict(response, "get_team_with_sidelined")

    # ------------------------------------------------------------------
    # Fixtures
    # ------------------------------------------------------------------

    def iter_fixtures_by_season(
        self,
        season_id: int,
        per_page: int = 100,
        include: str = "participants;state;scores;round;stage;group",
    ) -> Iterable[Dict]:
        return self._iter_paginated_data(
            "fixtures",
            endpoint_name="iter_fixtures_by_season",
            params={
                "filters": f"fixtureSeasons:{season_id}",
                "per_page": per_page,
                "include": include,
            },
        )

    def get_fixture_with_statistics(self, fixture_id: int) -> Dict:
        response = self._get(
            f"fixtures/{fixture_id}",
            params={"include": "participants;statistics.type"},
        )
        return self._require_data_dict(response, "get_fixture_with_statistics")

    def get_fixture_lineups(self, fixture_id: int) -> Dict:
        response = self._get(
            f"fixtures/{fixture_id}",
            params={
                "include": (
                    "formations;lineups.player;lineups.position;"
                    "lineups.detailedPosition;lineups.details"
                )
            },
        )
        return self._require_data_dict(response, "get_fixture_lineups")

    # ------------------------------------------------------------------
    # Transfers
    # ------------------------------------------------------------------

    def iter_transfers_by_team(
        self,
        team_id: int,
        per_page: int = 50,
    ) -> Iterable[Dict]:
        return self._iter_paginated_data(
            f"transfers/teams/{team_id}",
            endpoint_name="iter_transfers_by_team",
            params={
                "per_page": per_page,
                "include": "player;fromTeam;toTeam;type",
            },
        )

    def iter_transfers_between_dates(
        self,
        start_date: date,
        end_date: date,
    ):
        return self._iter_paginated_data(
            f"transfers/between/{start_date.isoformat()}/{end_date.isoformat()}",
            endpoint_name="iter_transfers_between_dates",
            params={
                "include": "player;fromTeam;toTeam;type",
                "per_page": 50,
                "order": "asc",
            },
        )

    # ------------------------------------------------------------------
    # States
    # ------------------------------------------------------------------

    def iter_states(self) -> Iterable[Dict]:
        return self._iter_paginated_data(
            "states",
            endpoint_name="iter_states",
            params={},
        )

    def get_states_map(self) -> Dict[int, str]:
        out: Dict[int, str] = {}

        for state in self.iter_states():
            if "id" not in state:
                raise ValueError(f"states item missing 'id': {state!r}")

            if "state" not in state:
                raise ValueError(f"states item missing 'state': {state!r}")

            state_id = state["id"]
            state_code = state["state"]

            if type(state_id) is not int:
                raise ValueError(f"states.id must be int: {state_id!r}")

            if not isinstance(state_code, str) or not state_code.strip():
                raise ValueError(f"states.state must be non-empty string: {state_code!r}")

            out[state_id] = state_code.strip().upper()

        return out