"""스페인 2부 현재 시즌만 기존 수집기로 별도 DB에 저장해요."""
import argparse
import json

from . import CLUBELO_TEAMS, COMPETITION_ID, SEASON_ID, SEASON_NAME, require_test_database


def sync(*, apply=False):
    require_test_database()
    from one_touch_loader.core.db import transaction
    from one_touch_loader.core.sportmonks import SportmonksClient
    from one_touch_loader.loaders import fixtures_loader, seasons_loader, standings_loader, teams_loader
    from one_touch_loader.loaders.team_seasons_loader import SQL_UPSERT_TEAM_SEASON

    client = SportmonksClient()
    league = client.get_league_with_seasons(COMPETITION_ID)
    current = [s for s in league['seasons'] if s['is_current']]
    if len(current) != 1 or (current[0]['id'], current[0]['name']) != (SEASON_ID, SEASON_NAME):
        raise ValueError('Sportmonks current season differs from the verified test season')
    participants = list(client.iter_teams_by_season(SEASON_ID))
    if {p['id'] for p in participants} != set(CLUBELO_TEAMS.values()):
        raise ValueError('Season participants differ from the verified ClubElo mapping')
    teams = [teams_loader._team_row(p, 'live-test participant') for p in participants]
    if apply:
        with transaction() as conn, conn.cursor() as cur:
            cur.execute('''INSERT INTO competitions
                (competition_id,name,image_path,competition_type,name_ko,short_code)
                VALUES (%s,%s,%s,'league',%s,%s) ON DUPLICATE KEY UPDATE
                name=VALUES(name),image_path=VALUES(image_path)''',
                (COMPETITION_ID, league['name'], league['image_path'], '스페인 2부', league.get('short_code')))
            cur.executemany(seasons_loader.SQL_UPSERT_SEASON, [(SEASON_ID, COMPETITION_ID, SEASON_NAME, True)])
            cur.executemany(teams_loader.SQL_UPSERT_TEAM, teams)
            cur.executemany(SQL_UPSERT_TEAM_SEASON, [(row[0], SEASON_ID) for row in teams])
        fixtures_loader._upsert_fixture_states(fixtures_loader._fixture_state_rows(client))
    fixtures = fixtures_loader._collect_and_upsert(
        client, (SEASON_ID, COMPETITION_ID, SEASON_NAME, True), set(CLUBELO_TEAMS.values()),
        sync_participants=True, apply=apply)
    standings = standings_loader._standing_rows(client, SEASON_ID)
    if apply:
        standings_loader._replace_season(SEASON_ID, standings, clear_live=True)
    return {'apply': apply, 'teams': len(teams), 'fixtures': fixtures,
            'standings': len(standings)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    print(json.dumps(sync(apply=args.apply), ensure_ascii=False))


if __name__ == '__main__':
    main()
