"""출처와 ID를 대조한 감독 이름을 언어별로 같은 이름 카탈로그에 저장해요."""
import argparse
from pathlib import Path

from diagnostics import migrate_sportmonks_names as shared
from one_touch_loader.core.sportmonks import SPORTMONKS_COACH_NAME_OVERRIDES

# 한국어 입력 파일은 DB 반영을 마쳐 삭제했고, 남은 일본어·중국어 입력만 사용해요.
LOCALE_GROUPS = {'ja-zh': ('ja', 'zh')}
SPECS = {'coaches': {
    'id': 'coach_id', 'prefix': 'name', 'limit': 255, 'identity': {'name': 'name'},
}}


def configuration(locale_group='ja-zh'):
    suffix = locale_group.replace('-', '_')
    return {
        'name': f'coach_names_{suffix}',
        'seed_path': Path(__file__).with_name(f'coach_names.{locale_group}.json'),
        'sql_path': Path(__file__).resolve().parents[1] / f'one_touch_loader/sql/migrate_coach_names_{suffix}.sql',
        'specs': SPECS,
        'locales': LOCALE_GROUPS[locale_group],
    }


def reviewed_rows(locale_group='ja-zh'):
    config = configuration(locale_group)
    return shared.reviewed_rows(seed_path=config['seed_path'], specs=SPECS, locales=config['locales'])


def migrate_data(conn, locale_group='ja-zh'):
    shared.migrate_data(conn, entities=reviewed_rows(locale_group), specs=SPECS, locales=LOCALE_GROUPS[locale_group])


def reviewed_player_translation(current, profiles):
    english = profiles['en']
    # Garande처럼 감독과 연결 선수에 같은 잘못된 이름이 있어도 번역을 승인하지 않아요.
    verified_name = SPORTMONKS_COACH_NAME_OVERRIDES.get(current['coach_id'])
    if verified_name and shared.identity_value(english.get('display_name')) != verified_name:
        return None, ['name']
    if any(profile.get('id') != current['coach_id'] for profile in profiles.values()):
        return None, ['provider_id']
    if shared.identity_value(current['name']) != shared.identity_value(english.get('display_name')):
        return None, ['name']
    player_id = english.get('player_id')
    if player_id is None or any(profile.get('player_id') != player_id or not profile.get('player')
                                for profile in profiles.values()):
        return None, ['player_link']
    # 감독 최상위 이름은 번역되지 않아요. 연결된 선수도 기존 선수 이름과 같은 신원 검증을 거쳐요.
    player_identity = {'player_id': player_id, 'display_name': english.get('display_name'),
                       'full_name': english.get('name'), 'date_of_birth': english.get('date_of_birth'),
                       'nationality_id': english.get('nationality_id')}
    translated, conflicts = shared.reviewed_translation(
        'players', player_identity, {locale: profile['player'] for locale, profile in profiles.items()})
    if conflicts:
        return None, conflicts
    return {'coach_id': current['coach_id'], 'identity': {'name': current['name']},
            **{locale: translated[locale] for locale in shared.LOCALES},
            'player_identity': player_identity}, []


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--locale-group', choices=LOCALE_GROUPS, default='ja-zh')
    args, remaining = parser.parse_known_args()
    shared.run_name_migration(**configuration(args.locale_group), argv=remaining)


if __name__ == '__main__':
    main()
