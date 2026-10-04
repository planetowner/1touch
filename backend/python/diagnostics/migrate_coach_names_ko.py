"""첨부 명단과 ID를 대조한 감독의 한국어 이름을 기존 이름 카탈로그에 저장해요."""
from pathlib import Path

from diagnostics import migrate_sportmonks_names as shared

SEED_PATH = Path(__file__).with_name('coach_names.ko.json')
SQL_PATH = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_coach_names_ko.sql'
LOCALES = ('ko',)
SPECS = {'coaches': {
    'id': 'coach_id', 'prefix': 'name', 'limit': 255, 'identity': {'name': 'name'},
}}


def reviewed_rows():
    return shared.reviewed_rows(seed_path=SEED_PATH, specs=SPECS, locales=LOCALES)


def migrate_data(conn):
    shared.migrate_data(conn, entities=reviewed_rows(), specs=SPECS, locales=LOCALES)


def main():
    shared.run_name_migration(name='coach_names_ko', seed_path=SEED_PATH, sql_path=SQL_PATH,
                              specs=SPECS, locales=LOCALES)


if __name__ == '__main__':
    main()
