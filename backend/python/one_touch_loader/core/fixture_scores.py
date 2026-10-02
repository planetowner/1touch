"""공급사의 점수 종류를 홈·원정 순서로 읽어요."""

CURRENT_SCORE_TYPE_ID = 1525
PENALTY_SCORE_TYPE_ID = 5

# 공식 기록과 대조한 기존 값→진출팀이에요. 공급사가 바로잡으면 그 값을 그대로 사용해요.
AGGREGATE_WINNER_CORRECTIONS = {
    # 맨유가 원정 다득점으로 진출했어요.
    # https://www.uefa.com/newsfiles/UCL/2019/2026859_TS.pdf
    41794: (591, 14),
    # 토트넘이 맨시티·아약스에 원정 다득점으로 진출했어요.
    # https://www.uefa.com/uefachampionsleague/news/0250-0e999aee96ca-0b7d18bcada0-1000--man-city-4-3-tottenham-champions-league-at-a-glance/
    # https://www.uefa.com/uefachampionsleague/news/025d-0f575d3136e5-a7a6ad998126-1000--uefa-champions-league-classics-ajax-2-3-tottenham/
    41792: (9, 6),
    41789: (629, 6),
    # 리옹이 원정 다득점으로 진출했어요.
    # https://www.uefa.com/uefachampionsleague/news/0260-10137194d12d-ef20360d8d2a-1000--report-juve-2-1-lyon-agg-2-2-ol-win-on-away-goals/
    20933: (625, 79),
    # PSG와 레알은 승부차기로 진출했어요.
    # https://www.liverpoolfc.com/news/liverpool-knocked-out-champions-league-psg-penalties
    # https://www.uefa.com/newsfiles/UCL/2025/2044778_FR.pdf
    58611: (8, 591),
    58613: (7980, 3468),
}


def aggregate_winner(fixture):
    winner = (fixture['aggregate'] or {}).get('winner_participant_id')
    correction = AGGREGATE_WINNER_CORRECTIONS.get(fixture['aggregate_id'])
    if correction is not None and winner == correction[0]:
        return correction[1]
    return winner


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
