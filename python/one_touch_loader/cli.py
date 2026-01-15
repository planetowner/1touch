# python/one_touch_loader/cli.py
import sys
from one_touch_loader.loaders.big5_bootstrap import run_big5_bootstrap
from one_touch_loader.loaders.standings_loader import (
    build_all_standings, refresh_current_standings, compute_rank_delta_since_last_match
)
from one_touch_loader.loaders.points_pace import (
    build_points_pace_all, refresh_points_pace_current
)

USAGE = """
Usage:
  python -m one_touch_loader.cli big5
  python -m one_touch_loader.cli standings build
  python -m one_touch_loader.cli standings refresh-current
  python -m one_touch_loader.cli standings delta <league_id> <season_id> <team_id>
  python -m one_touch_loader.cli points-pace build
  python -m one_touch_loader.cli points-pace refresh-current
"""

def main():
    if len(sys.argv) < 2:
        print(USAGE); return
    cmd = sys.argv[1]

    if cmd == "big5":
        names = None
        if len(sys.argv) == 3:
            names = [x.strip() for x in sys.argv[2].split(",") if x.strip()]
        run_big5_bootstrap(names)
        print("Big5 bootstrap done.")

    elif cmd == "standings":
        if len(sys.argv) < 3:
            print(USAGE); return
        sub = sys.argv[2]
        if sub == "build":
            build_all_standings()
            print("Standings build done.")
        elif sub == "refresh-current":
            refresh_current_standings()
            print("Standings refresh-current done.")
        elif sub == "delta" and len(sys.argv) == 6:
            lid = int(sys.argv[3]); sid = int(sys.argv[4]); tid = int(sys.argv[5])
            delta, symbol = compute_rank_delta_since_last_match(tid, lid, sid)
            print(f"team {tid} @ league {lid} season {sid}: delta={delta} {symbol}")
        else:
            print(USAGE)

    elif cmd == "points-pace":
        if len(sys.argv) < 3:
            print(USAGE); return
        sub = sys.argv[2]
        if sub == "build":
            build_points_pace_all()
            print("Points pace build done.")
        elif sub == "refresh-current":
            refresh_points_pace_current()
            print("Points pace refresh-current done.")
        else:
            print(USAGE)

    else:
        print(USAGE)

if __name__ == "__main__":
    main()