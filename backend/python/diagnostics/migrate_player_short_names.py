"""네 언어의 선수 짧은 이름을 기존 이름과 구분해 저장해요."""
from pathlib import Path
from diagnostics import migrate_sportmonks_names as shared
from diagnostics.player_short_names import LOCALES

SEED_PATH = Path(__file__).with_name('player_short_names.json')
SQL_PATH = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_player_short_names.sql'
SPECS = {'players': {
    'id': 'player_id', 'prefix': 'short_name', 'limit': 255,
    'columns': {locale: 'short_name' if locale == 'en' else f'short_name_{locale}' for locale in LOCALES},
    'identity': {column: column for column in ('display_name', 'full_name', 'date_of_birth', 'nationality_id',
                                              'display_name_ko', 'display_name_ja', 'display_name_zh')},
}}


def reviewed_rows():
    return shared.reviewed_rows(seed_path=SEED_PATH, specs=SPECS, locales=LOCALES)


def migrate_data(conn):
    shared.migrate_data(conn, entities=reviewed_rows(), specs=SPECS, locales=LOCALES)


def main():
    shared.run_name_migration(name='player_short_names', seed_path=SEED_PATH, sql_path=SQL_PATH,
                              specs=SPECS, locales=LOCALES)


if __name__ == '__main__':
    main()
