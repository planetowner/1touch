import sys

from one_touch_loader.loaders.teams_loader import (
    collect_all_teams,
    collect_teams_for_competition_season,
)
from one_touch_loader.loaders.fixtures_loader import (
    collect_all_fixtures,
    collect_fixtures_for_competition_season,
)
from one_touch_loader.loaders.team_seasons_loader import (
    collect_all_team_seasons,
    collect_team_seasons_for_name,
)
from one_touch_loader.loaders.seasons_loader import collect_all_seasons
from one_touch_loader.loaders.standings_loader import (
    build_all_standings,
    refresh_current_standings,
    compute_rank_delta_since_last_match,
)
from one_touch_loader.loaders.xg_standings_loader import (
    build_all_xg_standings,
    refresh_current_xg_standings,
    build_xg_standings_for_season,
)
from one_touch_loader.loaders.highlights_loader import refresh_highlights
from one_touch_loader.loaders.injuries_loader import (
    refresh_current_injuries,
    refresh_team_injuries,
)
from one_touch_loader.loaders.team_squad_members_loader import (
    BIG5_COMPETITION_IDS,
    collect_all_squads,
    collect_squads_for_competition_season,
    refresh_current_squads,
    refresh_team_squad,
)
from one_touch_loader.loaders.players_loader import (
    collect_all_players,
    collect_players_for_competition_season,
)
from one_touch_loader.loaders.countries_loader import refresh_countries
from one_touch_loader.loaders.player_team_honours_loader import (
    refresh_player_team_honours,
)
from one_touch_loader.loaders.best_eleven_loader import (
    rebuild_best_eleven,
    refresh_best_eleven,
    validate_best_eleven,
)
from one_touch_loader.loaders.transfers_loader import (
    refresh_current_transfers,
    refresh_team_transfers,
)
from one_touch_loader.loaders.team_stats_loader import (
    refresh_fixture_team_stats,
    refresh_fixture_team_stats_for_season,
    refresh_fixture_team_stats_for_current_seasons,
)
from one_touch_loader.loaders.team_attribute_training_features_loader import (
    build_team_attribute_training_features_for_seasons,
    build_current_team_attribute_training_features,
)
from one_touch_loader.loaders.team_attribute_regression_trainer import (
    train_team_attribute_regression_weights,
)
from one_touch_loader.loaders.team_attribute_scores_loader import (
    build_team_attribute_group_scores,
    build_current_team_attribute_group_scores,
)
from one_touch_loader.loaders.team_attribute_refresh_loader import (
    refresh_current_team_attributes,
)


# 새 DB 재적재용으로 다시 만든 명령만 의존 순서대로 적어요.
# fixtures는 team-seasons, players는 countries와 fixtures, squads는 players,
# Capology 선수 ID와 주급은 앞 단계의 팀·선수 매핑을 사용해요.
# team-attributes는 fixture-details·standings를 집계한 뒤 학습하고 점수를 계산해요.
# best-eleven은 fixture-details의 라인업으로 시즌·포메이션별 대표 선발을 계산해요.
# injuries는 갱신된 현재 DB 스쿼드에 속한 선수의 부상만 저장해요.
USAGE = """
New database reload order (redesigned commands):

1. seasons
  python -m one_touch_loader.cli seasons all

2. teams
  python -m one_touch_loader.cli teams all
  python -m one_touch_loader.cli teams <season_name> <competition_id> [competition_id ...]

3. team-seasons
  python -m one_touch_loader.cli team-seasons all
  python -m one_touch_loader.cli team-seasons <season_name>

4. fixtures
  python -m one_touch_loader.cli fixtures all
  python -m one_touch_loader.cli fixtures <season_name> <competition_id>

5. countries
  python -m one_touch_loader.cli countries refresh

6. players
  python -m one_touch_loader.cli players all
  python -m one_touch_loader.cli players <season_name> <competition_id> [competition_id ...]
  python -m one_touch_loader.cli players refresh-honours <player_id>

7. squads
  python -m one_touch_loader.cli squads all
  python -m one_touch_loader.cli squads <season_name> <competition_id> [competition_id ...]
  python -m one_touch_loader.cli squads refresh-current
  python -m one_touch_loader.cli squads refresh-team <team_id>

"""


def _parse_team_ids_csv(value: str) -> list[int]:
    return [int(x.strip()) for x in value.split(",") if x.strip()]


def _parse_competition_ids(values: list[str]) -> list[int]:
    competition_ids: list[int] = []
    seen: set[int] = set()

    for value in values:
        competition_id = int(value)
        if competition_id not in seen:
            seen.add(competition_id)
            competition_ids.append(competition_id)

    if not competition_ids:
        raise ValueError("At least one competition_id is required")
    return competition_ids


from one_touch_loader.loaders.points_pace import (
    build_points_pace_all,
    refresh_points_pace_current,
    validate_points_pace,
)

def main():
    if len(sys.argv) < 2:
        print(USAGE)
        return
    cmd = sys.argv[1]

    if cmd == "countries":
        if len(sys.argv) == 3 and sys.argv[2] == "refresh":
            refresh_countries()
            print("Countries refresh done.")
        else:
            print(USAGE)

    elif cmd == "seasons":
        if len(sys.argv) == 3 and sys.argv[2] == "all":
            result = collect_all_seasons()
            print(
                "Seasons all done: "
                f"competitions={result['competition_count']} "
                f"seasons={result['season_count']}"
            )
        else:
            print(USAGE)

    elif cmd == "teams":
        if len(sys.argv) == 3 and sys.argv[2] == "all":
            result = collect_all_teams()
            print(
                "Teams all done: "
                f"collection_runs={result['collection_runs']}"
            )

        elif len(sys.argv) >= 4:
            season_name = sys.argv[2]
            competition_ids = _parse_competition_ids(sys.argv[3:])
            for competition_id in competition_ids:
                result = collect_teams_for_competition_season(
                    season_name,
                    competition_id,
                )
                print(
                    "Teams competition done: "
                    f"season={season_name} "
                    f"competition={competition_id} "
                    f"result={result}"
                )
            print(
                "Teams season done: "
                f"season={season_name} competitions={competition_ids}"
            )

        else:
            print(USAGE)

    elif cmd == "team-seasons":
        if len(sys.argv) == 3 and sys.argv[2] == "all":
            result = collect_all_team_seasons()
            print(
                "Team-seasons all done: "
                f"seasons={result['processed_seasons']} "
                f"memberships={result['stored_memberships']} "
                f"pending={result['pending_seasons']}"
            )
        elif len(sys.argv) == 3:
            result = collect_team_seasons_for_name(sys.argv[2])
            print(
                "Team-seasons season done: "
                f"season={sys.argv[2]} "
                f"season_ids={result['processed_seasons']} "
                f"memberships={result['stored_memberships']} "
                f"pending={result['pending_seasons']}"
            )
        else:
            print(USAGE)

    elif cmd == "fixtures":
        if len(sys.argv) == 3 and sys.argv[2] == "all":
            result = collect_all_fixtures()
            print(
                "Fixtures all done: "
                f"collection_runs={result['collection_runs']} "
                f"fixtures={result['stored_fixtures']}"
            )
        elif len(sys.argv) == 4:
            season_name = sys.argv[2]
            competition_id = int(sys.argv[3])
            result = collect_fixtures_for_competition_season(
                season_name,
                competition_id,
            )
            print(
                "Fixtures competition done: "
                f"season={season_name} "
                f"competition={competition_id} "
                f"fixtures={result['stored_fixture_count']}"
            )
        else:
            print(USAGE)

    elif cmd == "standings":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "build":
            build_all_standings()
            print("Standings build done.")

        elif sub == "refresh-current":
            refresh_current_standings()
            print("Standings refresh-current done.")

        elif sub == "delta" and len(sys.argv) == 6:
            lid = int(sys.argv[3])
            sid = int(sys.argv[4])
            tid = int(sys.argv[5])

            delta, symbol = compute_rank_delta_since_last_match(tid, lid, sid)
            print(f"team {tid} @ league {lid} season {sid}: delta={delta} {symbol}")

        else:
            print(USAGE)

    elif cmd == "xg-standings":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "build":
            rows = build_all_xg_standings()
            print(f"xG standings build done. rows={rows}")

        elif sub == "refresh-current":
            rows = refresh_current_xg_standings()
            print(f"xG standings refresh-current done. rows={rows}")

        elif sub == "season" and len(sys.argv) == 5:
            league_id = int(sys.argv[3])
            season_id = int(sys.argv[4])

            rows = build_xg_standings_for_season(
                league_id,
                season_id,
                no_cache=True,
            )

            print(
                f"xG standings season done: "
                f"league_id={league_id} season_id={season_id} rows={rows}"
            )

        else:
            print(USAGE)

    elif cmd == "highlights":
        team_ids = None

        if len(sys.argv) >= 3 and sys.argv[2] == "refresh":
            if len(sys.argv) == 4:
                team_ids = _parse_team_ids_csv(sys.argv[3])

            refresh_highlights(team_ids)
            print("Highlights refresh done.")

        elif len(sys.argv) == 2:
            refresh_highlights()
            print("Highlights refresh done.")

        else:
            print(USAGE)

    elif cmd == "injuries":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "refresh-current":
            team_ids = None

            if len(sys.argv) == 4:
                team_ids = _parse_team_ids_csv(sys.argv[3])

            refresh_current_injuries(team_ids)
            print("Injuries refresh-current done.")

        elif sub == "refresh-team" and len(sys.argv) == 4:
            team_id = int(sys.argv[3])
            refresh_team_injuries(team_id)
            print(f"Injuries refresh-team done: team={team_id}")

        else:
            print(USAGE)

    elif cmd == "squads":
        if len(sys.argv) == 3 and sys.argv[2] == "all":
            result = collect_all_squads()
            print(
                "Squads all done: "
                f"team_seasons={result['loaded_team_seasons']} "
                f"members={result['stored_squad_members']}"
            )

        elif len(sys.argv) == 3 and sys.argv[2] == "refresh-current":
            refresh_current_squads()
            print("Squads refresh-current done.")

        elif len(sys.argv) == 4 and sys.argv[2] == "refresh-team":
            team_id = int(sys.argv[3])
            refresh_team_squad(team_id)
            print(f"Squads refresh-team done: team={team_id}")

        elif len(sys.argv) >= 4 and sys.argv[2] not in {
            "refresh-current",
            "refresh-team",
        }:
            season_name = sys.argv[2]
            competition_ids = _parse_competition_ids(sys.argv[3:])
            for competition_id in competition_ids:
                result = collect_squads_for_competition_season(
                    season_name,
                    competition_id,
                )
                print(
                    "Squads competition done: "
                    f"season={season_name} "
                    f"competition={competition_id} "
                    f"team_seasons={result['loaded_team_seasons']} "
                    f"members={result['stored_squad_members']}"
                )
            print(
                "Squads season done: "
                f"season={season_name} competitions={competition_ids}"
            )
        else:
            print(USAGE)

    elif cmd == "players":
        if len(sys.argv) == 3 and sys.argv[2] == "all":
            result = collect_all_players()
            print(
                "Players all done: "
                f"team_seasons={result['loaded_team_seasons']} "
                f"unique_players={result['unique_players']}"
            )

        elif len(sys.argv) == 4 and sys.argv[2] == "refresh-honours":
            player_id = int(sys.argv[3])
            refresh_player_team_honours(player_id)
            print(f"Players refresh-honours done: player={player_id}")

        elif len(sys.argv) >= 4 and sys.argv[2] not in {
            "refresh-honours",
        }:
            season_name = sys.argv[2]
            competition_ids = _parse_competition_ids(sys.argv[3:])
            for competition_id in competition_ids:
                result = collect_players_for_competition_season(
                    season_name,
                    competition_id,
                )
                print(
                    "Players competition done: "
                    f"season={season_name} "
                    f"competition={competition_id} "
                    f"team_seasons={result['loaded_team_seasons']} "
                    f"unique_players={result['unique_players']}"
                )
            print(
                "Players season done: "
                f"season={season_name} competitions={competition_ids}"
            )
        else:
            print(USAGE)

    elif cmd == "best-eleven":
        if len(sys.argv) == 2:
            # Fetch incomplete lineups across every competition in each current
            # Big 5 club campaign, then recompute affected canonical seasons.
            refresh_best_eleven()
            print("Best-eleven refresh done.")

        elif len(sys.argv) == 3 and sys.argv[2] == "rebuild-current":
            rebuild_best_eleven(current_only=True)

        elif len(sys.argv) == 3 and sys.argv[2] == "rebuild-all":
            rebuild_best_eleven(current_only=False)

        elif len(sys.argv) == 3 and sys.argv[2] == "validate":
            validate_best_eleven()

        else:
            print(USAGE)

    elif cmd == "transfers":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "refresh-current":
            team_ids = None

            if len(sys.argv) == 4:
                team_ids = _parse_team_ids_csv(sys.argv[3])

            refresh_current_transfers(team_ids)
            print("Transfers refresh-current done.")

        elif sub == "refresh-team" and len(sys.argv) == 4:
            team_id = int(sys.argv[3])
            refresh_team_transfers(team_id)
            print(f"Transfers refresh-team done: team={team_id}")

        else:
            print(USAGE)

    elif cmd == "team-stats":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "fixture" and len(sys.argv) == 4:
            fixture_id = int(sys.argv[3])
            refresh_fixture_team_stats(fixture_id)
            print(f"Team-stats fixture done: fixture={fixture_id}")

        elif sub == "season" and len(sys.argv) == 4:
            season_id = int(sys.argv[3])
            refresh_fixture_team_stats_for_season(season_id)
            print(f"Team-stats season done: season={season_id}")

        elif sub == "season" and len(sys.argv) == 5:
            season_id = int(sys.argv[3])
            only_status = sys.argv[4].strip().lower()

            if only_status not in {"past", "live", "upcoming"}:
                print(USAGE)
                return

            refresh_fixture_team_stats_for_season(season_id, only_status=only_status)
            print(f"Team-stats season done: season={season_id} status={only_status}")

        elif sub == "current" and len(sys.argv) == 3:
            refresh_fixture_team_stats_for_current_seasons()
            print("Team-stats current done: status=past")

        elif sub == "current" and len(sys.argv) == 4:
            only_status = sys.argv[3].strip().lower()

            if only_status not in {"past", "live", "upcoming"}:
                print(USAGE)
                return

            refresh_fixture_team_stats_for_current_seasons(only_status=only_status)
            print(f"Team-stats current done: status={only_status}")

        else:
            print(USAGE)

    elif cmd == "team-attributes":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "build-training-features" and len(sys.argv) == 3:
            count = build_team_attribute_training_features_for_seasons()
            print(f"Team-attributes training features done: rows={count}")

        elif sub == "build-current-features" and len(sys.argv) == 3:
            count = build_current_team_attribute_training_features()
            print(f"Team-attributes current training features done: rows={count}")

        elif sub == "train-regression" and len(sys.argv) == 3:
            model_id = train_team_attribute_regression_weights()
            print(f"Team-attributes regression training done: model_id={model_id}")

        elif sub == "build-scores" and len(sys.argv) == 3:
            count = build_team_attribute_group_scores()
            print(f"Team-attributes group scores done: rows={count}")

        elif sub == "build-current-scores" and len(sys.argv) == 3:
            count = build_current_team_attribute_group_scores()
            print(f"Team-attributes current group scores done: rows={count}")

        elif sub == "refresh-current" and len(sys.argv) in {3, 4}:
            update_fixtures = True

            if len(sys.argv) == 4:
                flag = sys.argv[3].strip().lower()

                if flag == "--skip-fixtures":
                    update_fixtures = False
                else:
                    print(USAGE)
                    return

            result = refresh_current_team_attributes(update_fixtures=update_fixtures)
            print(f"Team-attributes refresh-current done: {result}")

        else:
            print(USAGE)

    elif cmd == "points-pace":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "build":
            build_points_pace_all()
            print("Points pace build done.")

        elif sub == "refresh-current":
            refresh_points_pace_current()
            print("Points pace refresh-current done.")

        elif sub == "validate":
            validate_points_pace()

        else:
            print(USAGE)
    else:
        print(USAGE)


if __name__ == "__main__":
    main()
