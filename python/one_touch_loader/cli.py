import sys

from one_touch_loader.loaders.big5_bootstrap import run_big5_bootstrap
from one_touch_loader.loaders.standings_loader import (
    build_all_standings,
    refresh_current_standings,
    compute_rank_delta_since_last_match,
)
from one_touch_loader.loaders.points_pace import (
    build_points_pace_all,
    refresh_points_pace_current,
)
from one_touch_loader.loaders.highlights_loader import refresh_highlights
from one_touch_loader.loaders.injuries_loader import (
    refresh_current_injuries,
    refresh_team_injuries,
)
from one_touch_loader.loaders.best_eleven_loader import (
    full_build_best_eleven,
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
from one_touch_loader.loaders.team_features_loader import (
    build_fixture_team_features,
    build_fixture_team_features_for_season,
    build_fixture_team_features_for_current_seasons,
)
from one_touch_loader.loaders.team_scores_loader import (
    build_team_attribute_scores_for_fixture,
    build_team_attribute_scores_for_season,
    build_team_attribute_scores_for_current_seasons,
)

USAGE = """
Usage:
  python -m one_touch_loader.cli big5

  python -m one_touch_loader.cli standings build
  python -m one_touch_loader.cli standings refresh-current
  python -m one_touch_loader.cli standings delta <league_id> <season_id> <team_id>

  python -m one_touch_loader.cli points-pace build
  python -m one_touch_loader.cli points-pace refresh-current

  python -m one_touch_loader.cli highlights
  python -m one_touch_loader.cli highlights refresh
  python -m one_touch_loader.cli highlights refresh <team_id,team_id,...>

  python -m one_touch_loader.cli injuries refresh-current
  python -m one_touch_loader.cli injuries refresh-current <team_id,team_id,...>
  python -m one_touch_loader.cli injuries refresh-team <team_id>

  python -m one_touch_loader.cli best-eleven --full
  python -m one_touch_loader.cli best-eleven
  python -m one_touch_loader.cli best-eleven --days <N>
  python -m one_touch_loader.cli best-eleven validate

  python -m one_touch_loader.cli transfers refresh-current
  python -m one_touch_loader.cli transfers refresh-current <team_id,team_id,...>
  python -m one_touch_loader.cli transfers refresh-team <team_id>

  python -m one_touch_loader.cli team-stats fixture <fixture_id>
  python -m one_touch_loader.cli team-stats season <season_id>
  python -m one_touch_loader.cli team-stats season <season_id> <past|live|upcoming>
  python -m one_touch_loader.cli team-stats current
  python -m one_touch_loader.cli team-stats current <past|live|upcoming>

  python -m one_touch_loader.cli team-features fixture <fixture_id>
  python -m one_touch_loader.cli team-features season <season_id>
  python -m one_touch_loader.cli team-features current

  python -m one_touch_loader.cli team-scores fixture <fixture_id>
  python -m one_touch_loader.cli team-scores season <season_id>
  python -m one_touch_loader.cli team-scores current
"""


def main():
    if len(sys.argv) < 2:
        print(USAGE)
        return

    cmd = sys.argv[1]

    if cmd == "big5":
        names = None
        if len(sys.argv) == 3:
            names = [x.strip() for x in sys.argv[2].split(",") if x.strip()]
        run_big5_bootstrap(names)
        print("Big5 bootstrap done.")

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
        else:
            print(USAGE)

    elif cmd == "highlights":
        team_ids = None
        if len(sys.argv) >= 3 and sys.argv[2] == "refresh":
            if len(sys.argv) == 4:
                team_ids = [int(x.strip()) for x in sys.argv[3].split(",") if x.strip()]
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
                team_ids = [int(x.strip()) for x in sys.argv[3].split(",") if x.strip()]
            refresh_current_injuries(team_ids)
            print("Injuries refresh-current done.")

        elif sub == "refresh-team" and len(sys.argv) == 4:
            team_id = int(sys.argv[3])
            refresh_team_injuries(team_id)
            print(f"Injuries refresh-team done: team={team_id}")

        else:
            print(USAGE)

    elif cmd == "best-eleven":
        if len(sys.argv) >= 3 and sys.argv[2] == "--full":
            full_build_best_eleven()
            print("Best-eleven full build done.")
        elif len(sys.argv) >= 3 and sys.argv[2] == "validate":
            validate_best_eleven()
        else:
            days = 2
            if len(sys.argv) >= 4 and sys.argv[2] == "--days":
                days = int(sys.argv[3])
            refresh_best_eleven(lookback_days=days)
            print("Best-eleven refresh done.")

    elif cmd == "transfers":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "refresh-current":
            team_ids = None
            if len(sys.argv) == 4:
                team_ids = [int(x.strip()) for x in sys.argv[3].split(",") if x.strip()]
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

    elif cmd == "team-features":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "fixture" and len(sys.argv) == 4:
            fixture_id = int(sys.argv[3])
            build_fixture_team_features(fixture_id)
            print(f"Team-features fixture done: fixture={fixture_id}")

        elif sub == "season" and len(sys.argv) == 4:
            season_id = int(sys.argv[3])
            build_fixture_team_features_for_season(season_id)
            print(f"Team-features season done: season={season_id}")

        elif sub == "current" and len(sys.argv) == 3:
            build_fixture_team_features_for_current_seasons()
            print("Team-features current done.")

        else:
            print(USAGE)

    elif cmd == "team-scores":
        if len(sys.argv) < 3:
            print(USAGE)
            return

        sub = sys.argv[2]

        if sub == "fixture" and len(sys.argv) == 4:
            fixture_id = int(sys.argv[3])
            build_team_attribute_scores_for_fixture(fixture_id)
            print(f"Team-scores fixture done: fixture={fixture_id}")

        elif sub == "season" and len(sys.argv) == 4:
            season_id = int(sys.argv[3])
            build_team_attribute_scores_for_season(season_id)
            print(f"Team-scores season done: season={season_id}")

        elif sub == "current" and len(sys.argv) == 3:
            build_team_attribute_scores_for_current_seasons()
            print("Team-scores current done.")

        else:
            print(USAGE)

    else:
        print(USAGE)


if __name__ == "__main__":
    main()