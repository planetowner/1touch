from ..db import fetch_all_dict


def get_catalog() -> dict:
    # 여러 화면이 같은 시즌과 소속을 사용해요. 경기 유무로 소속을 추정하지 않아요.
    return {
        "teams": fetch_all_dict("SELECT team_id,name,short_name,short_code,image_path FROM teams ORDER BY name,team_id"),
        "competitions": fetch_all_dict("SELECT competition_id,name,short_code,image_path FROM competitions ORDER BY competition_id"),
        "seasons": fetch_all_dict("SELECT season_id,competition_id,name,is_current FROM seasons ORDER BY name DESC,competition_id,season_id"),
        "memberships": fetch_all_dict("""SELECT ts.team_id,ts.season_id,s.competition_id
            FROM team_seasons ts JOIN seasons s ON s.season_id=ts.season_id
            ORDER BY ts.team_id,ts.season_id"""),
    }
