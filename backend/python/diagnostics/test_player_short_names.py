"""이름 순서·복합 성·언어별 축약형과 저장 경계를 확인해요."""
from copy import deepcopy
import unittest
from unittest.mock import patch

with patch('mysql.connector.pooling.MySQLConnectionPool'):
    from diagnostics.player_short_names import english_short, short_names
    from diagnostics import migrate_player_short_names as migration
    from diagnostics import test_football_names as name_tests
    from one_touch_loader.core import football_names


class PlayerShortNamesTests(unittest.TestCase):
    def setUp(self):
        self.current = {'player_id': 184798, 'display_name': 'Lionel Messi', 'nationality_id': 44,
                        'display_name_ko': '리오넬 메시', 'display_name_ja': 'リオネル・メッシ',
                        'display_name_zh': '利昂内尔·梅西'}
        self.profiles = {'en': {'firstname': 'Lionel Andrés', 'lastname': 'Messi Cuccittini'},
                         'ja': {'firstname': 'リオネル', 'lastname': 'メッシ', 'common_name': 'リオネル'},
                         'zh': {'firstname': '利昂内尔', 'lastname': '梅西', 'common_name': '梅西'}}

    def test_four_languages_leave_original_display_unchanged(self):
        before = deepcopy(self.current)
        names, _ = short_names(self.current, self.profiles, {})
        self.assertEqual(names, {'en': 'L. Messi', 'ko': 'L. 메시', 'ja': 'L・メッシ', 'zh': 'L·梅西'})
        self.assertEqual(self.current, before)

    def test_compound_family_name_is_not_reduced_to_last_word(self):
        for display, given, expected in [('Frenkie de Jong', 'Frenkie', 'F. de Jong'),
                                         ('Marc ter Stegen', 'Marc-André', 'M. ter Stegen'),
                                         ('Trent Alexander-Arnold', 'Trent John', 'T. Alexander-Arnold')]:
            self.assertEqual(english_short(display, {'firstname': given})[0], expected)
        self.assertEqual(english_short('Neymar', {'firstname': 'Neymar'})[0], 'Neymar')
        self.assertEqual(english_short('Aaron James Ramsey', {'firstname': 'Aaron James', 'common_name': 'A. Ramsey'})[0], 'A. Ramsey')
        self.assertEqual(english_short('John Anderson', {'firstname': 'John', 'common_name': 'J. Son'})[0], 'J. Anderson')

    def test_first_name_only_does_not_become_a_short_name(self):
        self.current['display_name_ja'] = 'リオネル'
        self.profiles['ja']['lastname'] = None
        names, reasons = short_names(self.current, self.profiles, {})
        self.assertIsNone(names['ja'])
        self.assertEqual(reasons['ja'], 'unverified_local_name_parts')

    def test_upamecano_display_variant_uses_verified_provider_short_name(self):
        current = {'player_id': 33685, 'display_name': 'Dayot Upamecano', 'nationality_id': 17,
                   'display_name_ko': '다요 우파메카노', 'display_name_ja': 'ダヨ・ウパメカノ',
                   'display_name_zh': '达约特·乌帕梅卡诺'}
        profiles = {
            'en': {'firstname': 'Dayotchanculle', 'lastname': 'Upamecano', 'common_name': 'D. Upamecano'},
            'ja': {'firstname': 'デヨッチャンクレ', 'lastname': 'ウパメカノ', 'common_name': 'D・ウパメカノ'},
            'zh': {'firstname': '达约特·查恩库勒', 'lastname': '乌帕梅卡诺', 'common_name': '乌帕梅卡诺'},
        }
        before = deepcopy((current, profiles))
        names, reasons = short_names(current, profiles, {})
        self.assertEqual(names, {'en': 'D. Upamecano', 'ko': 'D. 우파메카노',
                                 'ja': 'D・ウパメカノ', 'zh': 'D·乌帕梅卡诺'})
        self.assertEqual(reasons['en'], 'provider_initial_name')
        self.assertEqual((current, profiles), before)

    def test_other_display_variants_share_provider_or_family_verification(self):
        cases = [
            ('Daniel Ward', 'Danny', 'Ward', 'D. Ward', 'D. Ward'),
            ('Danny Ings', 'Daniel William John', 'Ings', 'D. Ings', 'D. Ings'),
            ('Pepe Reina', 'José Manuel', 'Reina Páez', 'J. Reina Páez', 'P. Reina'),
            ('Danny Welbeck', 'Daniel Nii', 'Tackie Mensah Welbeck', 'D. Tackie Mensah Welbeck', 'D. Welbeck'),
            ('Ramiro Funes Mori', 'José Ramiro', 'Funes Mori', 'J. Funes Mori', 'R. Funes Mori'),
            ('Dele Alli', 'Bamidele', 'Alli', 'B. Alli', 'D. Alli'),
        ]
        for display, given, family, common, expected in cases:
            with self.subTest(display=display):
                profile = {'firstname': given, 'lastname': family, 'common_name': common}
                self.assertEqual(english_short(display, profile)[0], expected)
        self.current.update(display_name='Pepe Reina', display_name_ko='페페 레이나')
        self.profiles['en'] = {'firstname': 'José Manuel', 'lastname': 'Reina Páez', 'common_name': 'J. Reina Páez'}
        self.assertEqual(short_names(self.current, self.profiles, {})[0]['ko'], 'P. 레이나')

    def test_unrelated_profile_reversed_order_and_partial_word_stay_unverified(self):
        cases = [
            ('Edward Zenteno', 'Sean', 'Murray', 'S. Murray'),
            ('Solomon-Otabor Viv', 'Viv', 'Solomon-Otabor', 'V. Solomon-Otabor'),
            ('Koo Ja-Cheol', 'Ja-Cheol', 'Koo', 'J. Koo'),
            ('John Son', 'James', 'Anderson', 'J. Anderson'),
            ('John Anderson', 'James', 'Son', 'J. Son'),
            ('Dayot Upamecano', 'Dayotchanculle', None, 'X. Upamecano'),
        ]
        for display, given, family, common in cases:
            with self.subTest(display=display, common=common):
                self.assertEqual(english_short(display, {'firstname': given, 'lastname': family,
                                                         'common_name': common}),
                                 (None, 'unverified_display_order'))

    def test_native_family_first_names_and_existing_initials(self):
        current = {'player_id': 21437534, 'display_name': 'Kaoru Mitoma', 'nationality_id': 479,
                   'display_name_ko': '미토마 가오루', 'display_name_ja': '三笘 薫', 'display_name_zh': '三笘薫'}
        profiles = {'en': {'firstname': 'Kaoru'}, 'ja': {'firstname': '薫', 'lastname': '三笘'},
                    'zh': {'firstname': '薫', 'lastname': '三笘'}}
        names, _ = short_names(current, profiles, {})
        self.assertEqual(names, {'en': 'K. Mitoma', 'ko': '미토마 가오루', 'ja': '三笘 薫', 'zh': '三笘薫'})
        self.current['display_name_ja'] = 'L・メッシ'
        self.assertEqual(short_names(self.current, self.profiles, {})[0]['ja'], 'L・メッシ')
        self.current['display_name_ja'] = 'C・メッシ'
        self.assertIsNone(short_names(self.current, self.profiles, {})[0]['ja'])

    def test_known_alias_is_id_scoped_and_missing_translation_stays_missing(self):
        self.current.update(player_id=580, display_name='Cristiano Ronaldo', display_name_ko=None)
        self.profiles['en']['firstname'] = 'Cristiano Ronaldo'
        names, _ = short_names(self.current, self.profiles, {'580': {'zh': 'C罗'}})
        self.assertEqual(names['zh'], 'C罗')
        self.assertIsNone(names['ko'])

    def test_language_catalog_keeps_display_and_short_names_separate(self):
        for locale in ('en', 'ko', 'ja', 'zh'):
            values = [[(83, 'Team')], [(184798, 'Full')]]
            if locale in ('en', 'ko'):
                values.append([(83, 'Short team')])
            values.append([(184798, 'Short player')])
            values.append([(564, 'League')])
            with patch.object(football_names, 'fetch_all', side_effect=values) as fetch:
                result = football_names.localized_names(locale)
            self.assertEqual(result['players'], {'184798': 'Full'})
            self.assertEqual(result['player_short_names'], {'184798': 'Short player'})
            self.assertEqual(result['competitions'], {'564': 'League'})
            column = 'name' if locale == 'en' else f'name_{locale}'
            self.assertEqual(fetch.call_args.args[0],
                             f'SELECT competition_id,{column} FROM competitions '
                             f'WHERE {column} IS NOT NULL ORDER BY competition_id')
            if locale in ('ja', 'zh'):
                self.assertEqual(result['team_short_names'], {})

    def test_new_endpoint_requires_auth_and_rejects_unknown_locale(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from one_touch_loader.api.routes.football_names import router
        from one_touch_loader.api.deps import get_user_id
        app = FastAPI()
        app.include_router(router, prefix='/v1')
        client = TestClient(app)
        self.assertEqual(client.get('/v1/football-names/ja/display').status_code, 401)
        app.dependency_overrides[get_user_id] = lambda: 1
        self.assertEqual(client.get('/v1/football-names/invalid/display').status_code, 422)
        with patch.object(football_names, 'fetch_all', side_effect=[[], [(184798, 'リオネル・メッシ')], [(184798, 'L・メッシ')], [(564, 'ラ・リーガ')]]):
            result = client.get('/v1/football-names/ja/display')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.json()['player_short_names'], {'184798': 'L・メッシ'})
        self.assertEqual(result.json()['competitions'], {'564': 'ラ・リーガ'})

    def test_migration_preserves_existing_names_and_rolls_back_all_languages(self):
        fixture = name_tests.MigrationTests()
        fixture.setUp()
        try:
            for column in migration.SPECS['players']['columns'].values():
                fixture.db.execute(f'ALTER TABLE players ADD COLUMN {column} TEXT')
            fixture.db.execute("UPDATE players SET display_name_ko='해리 케인' WHERE player_id=997")
            fixture.db.commit()
            names = {'players': [{'player_id': 997, 'en': 'H. Kane', 'ko': 'H. 케인', 'ja': 'H・ケイン', 'zh': 'H·凯恩'}]}
            before = fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall()
            with patch.object(migration, 'reviewed_rows', return_value=names):
                migration.migrate_data(fixture.connection)
                first = fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall()
                migration.migrate_data(fixture.connection)
                self.assertEqual(fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall(), first)
            self.assertEqual([row[:-4] for row in first], [row[:-4] for row in before])
            self.assertEqual(first[-1][-4:], ('H. Kane', 'H. 케인', 'H・ケイン', 'H·凯恩'))
            names['players'].insert(0, {'player_id': 1, 'en': 'O. Full', 'ko': None, 'ja': None, 'zh': None})
            names['players'][1]['zh'] = 'wrong replacement'
            with patch.object(migration, 'reviewed_rows', return_value=names), self.assertRaises(ValueError):
                migration.migrate_data(fixture.connection)
            self.assertEqual(fixture.db.execute('SELECT * FROM players ORDER BY player_id').fetchall(), first)
        finally:
            fixture.tearDown()


if __name__ == '__main__':
    unittest.main()
