"""공급사의 점수 종류를 홈·원정 순서로 읽어요."""

CURRENT_SCORE_TYPE_ID = 1525
PENALTY_SCORE_TYPE_ID = 5


def score_pair(fixture, home_team_id, away_team_id, type_id):
    values = {s['participant_id']: s['score']['goals']
              for s in fixture['scores'] if s['type_id'] == type_id}
    # 공식 징계 공문은 Cerignola 1–0 Avellino예요. 공급사는 이 경기 점수를 반대로 줬어요.
    # https://img.legaseriea.it/vimages/6899f41e/Cu15.pdf
    if (fixture['id'] == 19431119 and type_id == CURRENT_SCORE_TYPE_ID
            and values == {133057: 0, 6911: 1}):
        values = {133057: 1, 6911: 0}
    if not values:
        return None, None
    return values[home_team_id], values[away_team_id]
