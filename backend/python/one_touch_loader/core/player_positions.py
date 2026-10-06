"""화면과 순위는 현재·과거 모두 해당 시즌의 Sportmonks 스쿼드 포지션을 사용해요."""
from collections import defaultdict

from .fixture_states import COMPLETED_STATE_IDS
from .player_appearances import APPEARED, MATCH_FROM
from .player_match_metrics import POSITION_GROUPS
from .player_membership import team_for_appearances


def season_player_position_ids(fetch, season_name, as_of, *, season_id=None, player_ids=None):
    if player_ids is not None and not player_ids:
        return {}
    scope = '' if season_id is None else ' AND s.season_id=%s'
    params = (season_name,) if season_id is None else (season_name, season_id)
    if player_ids is not None:
        scope += f" AND sm.player_id IN ({','.join(['%s'] * len(player_ids))})"
        params += tuple(player_ids)
    rows = fetch(f"""SELECT sm.player_id,sm.team_id,sm.position_group_id
        FROM team_squad_members sm JOIN seasons s ON s.season_id=sm.season_id
        WHERE s.name=%s{scope} ORDER BY s.season_id DESC,sm.team_id""", params)
    rosters = defaultdict(list)
    for row in rows:
        rosters[row['player_id']].append(row)
    # 이적 전후 스쿼드의 포지션이 다르면 기존 소속 선택 규칙으로 최근 팀을 골라요.
    # 경기별 포지션이나 출전 비율로 원본 포지션을 다시 분류하지 않아요.
    conflicting = sorted(pid for pid, roster in rosters.items()
                         if len({r['position_group_id'] for r in roster}) > 1)
    appearances = defaultdict(list)
    if conflicting:
        completed = ','.join(map(str, COMPLETED_STATE_IDS))
        match_scope = '' if season_id is None else ' AND s.season_id=%s'
        match_params = (season_name, as_of, *conflicting)
        if season_id is not None:
            match_params += (season_id,)
        for row in fetch('SELECT fl.player_id,fl.team_id,f.starting_at ' + MATCH_FROM
                         + f" WHERE s.name=%s AND f.starting_at<=%s AND f.state_id IN ({completed})"
                         + f" AND {APPEARED} AND fl.player_id IN ({','.join(['%s'] * len(conflicting))})"
                         + match_scope, match_params):
            appearances[row['player_id']].append(row)
    return {pid: team_for_appearances(roster, appearances[pid])['position_group_id']
            for pid, roster in rosters.items()}


def season_player_positions(fetch, season_name, as_of, *, player_ids=None):
    return {pid: POSITION_GROUPS.get(position) for pid, position in
            season_player_position_ids(fetch, season_name, as_of, player_ids=player_ids).items()}
