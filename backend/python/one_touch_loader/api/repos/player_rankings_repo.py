from datetime import datetime, timezone

from ..db import fetch_all_dict, fetch_one_dict
from ...core.player_rating_percentile import (
    RATING_COMPETITION_IDS, REFERENCE_START_SEASON_NAME, display_score, rank_players,
)


def get_player_rankings(season_id: int, *, limit: int = 20, offset: int = 0) -> dict | None:
    league_ids = ','.join(map(str, RATING_COMPETITION_IDS))
    metadata = fetch_one_dict(f"""
        SELECT s.competition_id, s.season_id, s.name AS season_name,
               ref.start_season_name, s.name AS end_season_name, ref.minimum_rated_matches,
               UNIX_TIMESTAMP(ref.updated_at) AS reference_updated_epoch,
               (SELECT COUNT(*) FROM player_rating_reference_samples sample
                JOIN seasons sample_season ON sample_season.season_id=sample.season_id
                WHERE sample.competition_id IN ({league_ids})
                  AND sample_season.name BETWEEN ref.start_season_name AND s.name) AS sample_count
        FROM seasons s
        JOIN player_rating_references ref ON ref.competition_id=s.competition_id
        WHERE s.season_id=%s
          AND s.competition_id IN ({league_ids})
          AND s.name BETWEEN ref.start_season_name AND ref.end_season_name
          AND (SELECT COUNT(*) FROM player_rating_references ready
               WHERE ready.competition_id IN ({league_ids}) AND ready.start_season_name=%s)=%s
    """, (season_id, REFERENCE_START_SEASON_NAME, len(RATING_COMPETITION_IDS)))
    if metadata is None:
        return None
    rows = fetch_all_dict("""
        SELECT score.player_id, p.display_name AS player_name, p.image_path AS player_image,
               score.rated_matches, score.rating_sum, score.percentile_score,
               UNIX_TIMESTAMP(score.updated_at) AS updated_epoch
        FROM player_rating_scores score
        JOIN players p ON p.player_id=score.player_id
        WHERE score.season_id=%s AND score.competition_id=%s
    """, (season_id, metadata["competition_id"]))
    # SQL 평균의 반올림이나 표시 점수의 동점으로 순서가 바뀌지 않게 합계÷경기 수를 정확히 비교해요.
    ranked = rank_players(rows)
    items = []
    for row in ranked[offset:offset + limit]:
        row.pop("rating_sum")
        row["updated_at"] = datetime.fromtimestamp(float(row.pop("updated_epoch")), tz=timezone.utc)
        row["display_score"] = display_score(row["percentile_score"])
        row["percentile_score"] = float(row["percentile_score"])
        items.append(row)
    return {
        "competition_id": metadata["competition_id"], "season_id": season_id,
        "season_name": metadata["season_name"],
        "reference": {
            "start_season_name": metadata["start_season_name"],
            "end_season_name": metadata["end_season_name"],
            "minimum_rated_matches": metadata["minimum_rated_matches"],
            "competition_ids": list(RATING_COMPETITION_IDS),
            "sample_count": metadata["sample_count"],
            "updated_at": datetime.fromtimestamp(float(metadata["reference_updated_epoch"]), tz=timezone.utc),
        },
        "total": len(ranked), "limit": limit, "offset": offset, "items": items,
    }
