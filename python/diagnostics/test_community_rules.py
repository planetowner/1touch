"""언어별 공통 안내와 기존 회원 접근 규칙을 실제 격리 MySQL에서 확인해요."""
import os
from unittest.mock import patch

from diagnostics.test_user_community import CommunityDatabaseCase
from diagnostics.verify_community_rules import verify_schema


class RulesTests(CommunityDatabaseCase):
    def test_migration_preserves_other_tables_and_rejects_an_unreviewed_existing_body(self):
        tables = ("users", "user_following_teams", "user_sessions")
        original = {table: self.execute(f"SELECT * FROM {table}") for table in tables}
        verify_schema(before=True, print_report=False)
        self.execute("INSERT INTO community_rules VALUES (1,'Existing text without a language')")
        with self.assertRaisesRegex(AssertionError, "no longer empty"):
            verify_schema(before=True, print_report=False)
        self.execute("DELETE FROM community_rules")
        self.apply_rules_schema()
        verify_schema(before=False, print_report=False)
        for table in tables:
            self.assertEqual(self.execute(f"SELECT * FROM {table}"), original[table])

    def test_languages_are_independent_shared_across_teams_and_missing_text_is_not_substituted(self):
        self.apply_rules_schema()
        with patch.dict(os.environ, {"COMMUNITY_ADMIN_USER_IDS": str(self.a)}):
            for language, body in (("ko", "커뮤니티에서 지켜주세요\n\n1. 개인정보를 공유하지 마세요."),
                                   ("en", "Community Ground Rules\n\n1. Do not share personal information.")):
                self.assertEqual(self.request("GET", f"/v1/community/rules?team_id=6&language={language}").json(), {"rules": None})
                saved = self.request("PUT", f"/v1/admin/community/rules?language={language}", json={"body": body})
                self.assertEqual(saved.status_code, 200, saved.text)
                for team, token in ((6, self.token_a), (503, self.token_b)):
                    self.assertEqual(self.request("GET", f"/v1/community/rules?team_id={team}&language={language}", token).json(),
                                     {"rules": {"body": body}})
            self.request("PUT", "/v1/admin/community/rules?language=ko", json={"body": "변경한 한국어 안내"})
            self.assertEqual(self.request("GET", "/v1/admin/community/rules?language=en").json(), {"rules": {"body": body}})
        self.assertEqual(verify_schema(before=False, print_report=False)["tables"]["community_rules"], 2)

    def test_language_is_explicit_and_unprivileged_writes_are_rejected(self):
        self.apply_rules_schema()
        with patch.dict(os.environ, {"COMMUNITY_ADMIN_USER_IDS": str(self.a)}):
            for language in (None, "kr", "fr", "KO"):
                query = {} if language is None else {"language": language}
                self.assertEqual(self.request("GET", "/v1/community/rules", params={"team_id": 6, **query}).status_code, 422)
                self.assertEqual(self.request("GET", "/v1/admin/community/rules", params=query).status_code, 422)
                self.assertEqual(self.request("PUT", "/v1/admin/community/rules", params=query, json={"body": "Rules"}).status_code, 422)
            for language in ("ko", "en"):
                self.assertEqual(self.request("PUT", f"/v1/admin/community/rules?language={language}",
                                              self.token_b, json={"body": "Rules"}).status_code, 403)
        self.assertEqual(self.execute("SELECT * FROM community_rules"), [])
