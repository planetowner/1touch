from __future__ import annotations

from ..db import fetch_all_dict, fetch_one_dict


def get_fixture_expected_goals(fixture_id: int) -> dict | None:
    row = fetch_one_dict("""
        SELECT home_xg, away_xg FROM fixture_expected_goals WHERE fixture_id=%s
    """, (fixture_id,))
    if row is not None:
        # 같은 경기의 xGA는 상대 xG예요. 별도 저장값이 서로 어긋나지 않게 해요.
        row.update(home_xga=row["away_xg"], away_xga=row["home_xg"], provider="understat")
    return row


def list_fixture_player_expected_goals(fixture_id: int) -> list[dict]:
    return fetch_all_dict("""
        SELECT x.player_id, p.display_name AS player_name, x.xg
        FROM fixture_player_expected_goals x JOIN players p ON p.player_id=x.player_id
        WHERE x.fixture_id=%s ORDER BY x.player_id
    """, (fixture_id,))


def list_fixture_shots(fixture_id: int) -> list[dict]:
    return fetch_all_dict("""
        SELECT s.shot_id, s.team_id, s.player_id, p.display_name AS player_name,
               s.minute, s.x, s.y, s.xg, s.result
        FROM fixture_shots s JOIN players p ON p.player_id=s.player_id
        WHERE s.fixture_id=%s ORDER BY s.minute, s.shot_id
    """, (fixture_id,))


def list_xg_standings(competition_id: int, season_id: int) -> list[dict]:
    return fetch_all_dict("""
        SELECT x.position, x.team_id, t.name AS team_name, t.image_path AS team_logo,
               x.matches_played, x.xg, x.xga, x.xpts
        FROM xg_standings x JOIN seasons s ON s.season_id=x.season_id
        JOIN teams t ON t.team_id=x.team_id
        WHERE x.season_id=%s AND s.competition_id=%s ORDER BY x.position, x.team_id
    """, (season_id, competition_id))
