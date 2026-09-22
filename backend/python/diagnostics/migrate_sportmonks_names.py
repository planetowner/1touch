"""확인한 Sportmonks 일본어·중국어 이름만 기존 팀·선수에 저장해요."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import unicodedata

from diagnostics.migrate_football_names import save_name_columns
from one_touch_loader.core.db import fetch_all

SEED_PATH = Path(__file__).with_name('football_names.ja-zh.json')
SQL_PATH = Path(__file__).resolve().parents[1] / 'one_touch_loader/sql/migrate_sportmonks_names.sql'
SPECS = {
    'teams': {'id': 'team_id', 'source_field': 'name', 'prefix': 'name', 'limit': 160,
              'identity': {'name': 'name'}},
    'players': {'id': 'player_id', 'source_field': 'display_name', 'prefix': 'display_name', 'limit': 255,
                'identity': {'display_name': 'display_name', 'full_name': 'name',
                             'date_of_birth': 'date_of_birth', 'nationality_id': 'nationality_id'}},
}
LOCALES = ('ja', 'zh')


def identity_value(value):
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    if isinstance(value, str):
        return ' '.join(unicodedata.normalize('NFKC', value).split())
    return value


def localized_value(value, english, locale):
    # 번역 미제공 시 영어가 반환돼요. 영어를 번역 완료 값으로 저장하지 않아요.
    if not isinstance(value, str) or not value.strip() or identity_value(value) == identity_value(english):
        return None
    has_han = any('\u3400' <= char <= '\u4dbf' or '\u4e00' <= char <= '\u9fff'
                  or '\uf900' <= char <= '\ufaff' or '\U00020000' <= char <= '\U0002ebef' for char in value)
    has_kana = any('\u3040' <= char <= '\u30ff' or '\u31f0' <= char <= '\u31ff'
                   or '\uff65' <= char <= '\uff9f' for char in value)
    return value if has_han or (locale == 'ja' and has_kana) else None


def reviewed_translation(kind, current, profiles):
    spec = SPECS[kind]
    key = current[spec['id']]
    english = profiles['en']
    if any(profile.get('id') != key for profile in profiles.values()):
        return None, ['provider_id']
    conflicts = [column for column, source in spec['identity'].items()
                 if identity_value(current[column]) != identity_value(english.get(source))]
    # 기존에 수정한 혼합 프로필을 다른 언어 이름으로 다시 연결하지 않아요.
    if conflicts:
        return None, conflicts
    if kind == 'players' and any(profile.get(field) != english.get(field)
                                for locale, profile in profiles.items() if locale != 'en'
                                for field in ('date_of_birth', 'nationality_id')):
        return None, ['locale_identity']
    names = {locale: localized_value(profiles[locale].get(spec['source_field']),
                                    english.get(spec['source_field']), locale) for locale in LOCALES}
    return {spec['id']: key, 'identity': {column: current[column] for column in spec['identity']}, **names}, []


def name_column(spec, locale):
    return spec.get('columns', {}).get(locale, f"{spec['prefix']}_{locale}")


def reviewed_rows(*, seed_path=None, specs=SPECS, locales=LOCALES):
    entities = json.loads((seed_path or SEED_PATH).read_text(encoding='utf-8'))['entities']
    if set(entities) != set(specs):
        raise ValueError('Unexpected localized-name tables')
    for table, rows in entities.items():
        spec = specs[table]
        if len({row[spec['id']] for row in rows}) != len(rows):
            raise ValueError(f'Duplicate {table} IDs')
        for row in rows:
            if set(row['identity']) != set(spec['identity']) or not any(row[locale] is not None for locale in locales):
                raise ValueError(f'Incomplete {table} identity or names')
            for locale in locales:
                value = row[locale]
                if value is not None and (not isinstance(value, str) or not value.strip() or len(value) > spec['limit']):
                    raise ValueError(f'Invalid {table} {locale} name')
    return entities


def verify_schema(*, before, specs=SPECS, locales=LOCALES):
    present = []
    for table, spec in specs.items():
        for locale in locales:
            column = name_column(spec, locale)
            actual = fetch_all('SELECT column_type,is_nullable FROM information_schema.columns '
                               'WHERE table_schema=DATABASE() AND table_name=%s AND column_name=%s', (table, column))
            if not actual and before:
                present.append(False)
            elif actual == [(f"varchar({spec['limit']})", 'YES')]:
                present.append(True)
            else:
                raise ValueError(f'Unexpected schema: {table}.{column}')
    if any(present) and not all(present):
        raise ValueError('Incomplete name schema; inspect before retrying')
    return all(present)


def preview(*, entities=None, specs=SPECS, locales=LOCALES):
    ready = verify_schema(before=True, specs=specs, locales=locales)
    summary = {}
    for table, rows in (reviewed_rows() if entities is None else entities).items():
        spec = specs[table]
        columns = [spec['id'], *spec['identity'], *(name_column(spec, locale) for locale in locales)]
        selected = columns if ready else columns[:-len(locales)] + ['NULL'] * len(locales)
        saved = {row[0]: dict(zip(columns, row)) for row in fetch_all(f"SELECT {','.join(selected)} FROM {table}")}
        updates = 0
        for row in rows:
            key = row[spec['id']]
            if key not in saved or any(identity_value(saved[key][column]) != identity_value(value)
                                      for column, value in row['identity'].items()):
                raise ValueError(f'Reviewed {table} identity changed: {key}')
            for locale in locales:
                value = row[locale]
                if value is None:
                    continue
                old = saved[key][name_column(spec, locale)]
                if old not in (None, value):
                    raise ValueError(f'Existing {table} {locale} name differs: {key}')
                updates += old != value
        summary[table] = {'reviewed': len(rows), 'updates': updates,
                          **{locale: sum(row[locale] is not None for row in rows) for locale in locales}}
    return ready, summary


def migrate_data(conn, *, entities=None, specs=SPECS, locales=LOCALES):
    entities = reviewed_rows() if entities is None else entities
    names = {table: {name_column(specs[table], locale):
                     {row[specs[table]['id']]: row[locale] for row in rows if row[locale] is not None}
                     for locale in locales} for table, rows in entities.items()}
    save_name_columns(conn, names=names, identifiers={table: spec['id'] for table, spec in specs.items()})


def main():
    run_name_migration(name='sportmonks_names_ja_zh', seed_path=SEED_PATH, sql_path=SQL_PATH,
                       specs=SPECS, locales=LOCALES)


def run_name_migration(*, name, seed_path, sql_path, specs, locales):
    # 일반 이름과 짧은 이름은 입력·컬럼만 다르고 검증·백업·저장 순서는 같아요.
    parser = argparse.ArgumentParser(description='Preview names; use --apply to back up and save.')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    entities = reviewed_rows(seed_path=seed_path, specs=specs, locales=locales)
    ready, summary = preview(entities=entities, specs=specs, locales=locales)
    print(json.dumps({'schema_ready': ready, 'tables': summary}, ensure_ascii=False), flush=True)
    if not args.apply or not any(row['updates'] for row in summary.values()):
        return
    from diagnostics.run_minimal_migration import run_migration
    run_migration(name=name, tables=tuple(specs), sql_paths=() if ready else (sql_path,),
                  verify_schema=lambda **kwargs: verify_schema(**kwargs, specs=specs, locales=locales),
                  migrate_data=lambda conn: migrate_data(conn, entities=entities, specs=specs, locales=locales))
    _, after = preview(entities=entities, specs=specs, locales=locales)
    if any(row['updates'] for row in after.values()):
        raise ValueError('Saved names differ from reviewed values')
    print(json.dumps({'verified': after}, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
