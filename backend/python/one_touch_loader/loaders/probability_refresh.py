"""기존 예약 실행에서 Ranking을 한 번 읽고 모든 확률 계산에 공유해요."""
import argparse
from pathlib import Path

from . import cup_betting_loader, european_probability_loader, probability_loader, tournament_bracket_loader


def refresh(*, apply=False, simulations=100000, seed=20260917, cache_dir=None):
    mapping = probability_loader.read_clubelo_mapping()
    histories = probability_loader.refresh_histories(mapping, apply=apply, cache_dir=cache_dir)
    brackets = tournament_bracket_loader.refresh(apply=apply)
    league = probability_loader.refresh(apply=apply, simulations=simulations, seed=seed, histories=histories)
    cup = cup_betting_loader.refresh(apply=apply, histories=histories)
    europe = european_probability_loader.refresh(apply=apply, histories=histories, simulations=simulations,
                                                  seed=seed, brackets=brackets)
    return {"applied": apply, "strength_source_url": "https://clubelo.com/Ranking",
            "source_teams": len(mapping), "league": league, "cup": cup, "europe": europe,
            "brackets": [{k: b[k] for k in ('season_id', 'status', 'path_status')} for b in brackets]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulations", type=int, default=100000)
    parser.add_argument("--seed", type=int, default=20260917)
    parser.add_argument("--cache-dir", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    print(probability_loader._dump(refresh(apply=args.apply, simulations=args.simulations,
                                          seed=args.seed, cache_dir=args.cache_dir)))


if __name__ == "__main__":
    main()
