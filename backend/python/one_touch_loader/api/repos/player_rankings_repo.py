from datetime import datetime, timezone

from ..db import fetch_all_dict, fetch_one_dict
from ...core.player_rating_percentile import display_score, rank_players


def get_player_rankings(season_id: int, *, limit: int = 20, offset: int = 0) -> dict | None:
    metadata = fetch_one_dict("""
        SELECT s.competition_id, s.season_id, s.name AS season_name,
               ref.start_season_name, ref.end_season_name, ref.minimum_rated_matches,
               UNIX_TIMESTAMP(ref.frozen_at) AS frozen_epoch,
               (SELECT COUNT(*) FROM player_rating_reference_samples sample
                WHERE sample.competition_id=ref.competition_id) AS sample_count
        FROM seasons s
        JOIN player_rating_references ref ON ref.competition_id=s.competition_id
        WHERE s.season_id=%s
    """, (season_id,))
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
            "sample_count": metadata["sample_count"],
            "frozen_at": datetime.fromtimestamp(float(metadata["frozen_epoch"]), tz=timezone.utc),
        },
        "total": len(ranked), "limit": limit, "offset": offset, "items": items,
    }
