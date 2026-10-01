"""안내 테이블을 없앤 뒤에도 문구·접근 권한·기존 데이터가 유지되는지 검사해요."""
from pathlib import Path
from unittest.mock import patch

from diagnostics.test_user_community import CommunityDatabaseCase
from diagnostics.verify_static_community_rules import verify_schema


class RulesTests(CommunityDatabaseCase):
    def remove_rules_table(self):
        self.apply_rules_schema()
        self.execute("INSERT INTO community_rules VALUES ('ko','Old Korean'),('en','Old English')")
        verify_schema(before=True, print_report=False)
        sql = Path(__file__).resolve().parents[1] / "one_touch_loader/sql/migrate_static_community_rules.sql"
        self.execute(sql.read_text(encoding="utf-8"))
        verify_schema(before=False, print_report=False)

    def test_removal_preserves_members_sessions_followers_and_published_content(self):
        post_id = self.post()
        self.execute("INSERT INTO post_comments (post_id,user_id,body,created_at) VALUES (%s,%s,'Comment',UTC_TIMESTAMP())",
                     (post_id, self.a))
        tables = ("users", "user_following_teams", "user_sessions", "posts", "post_comments")
        original = {table: self.execute(f"SELECT * FROM {table}") for table in tables}
        self.remove_rules_table()
        for table in tables:
            self.assertEqual(self.execute(f"SELECT * FROM {table}"), original[table])
        with self.assertRaises(AssertionError):
            verify_schema(before=True, print_report=False)

    def test_same_message_keys_are_available_to_each_home_team_without_a_rules_table(self):
        self.remove_rules_table()
        one = self.request("GET", "/v1/community/rules?team_id=6")
        two = self.request("GET", "/v1/community/rules?team_id=503", self.token_b)
        self.assertEqual(one.status_code, 200, one.text)
        self.assertEqual(one.json(), two.json())
        rules = one.json()["rules"]
        self.assertEqual(set(rules), {"title", "items"})
        self.assertEqual(rules["title"], "Community Ground Rules")
        self.assertEqual(len(rules["items"]), 5)
        self.assertEqual(rules["items"][0]["title"], "Keep it about football")
        self.assertTrue(all(set(item) == {"title", "body"} and item["body"] for item in rules["items"]))
        self.assertEqual(rules["items"][2]["body"], "Banter and friendly rivalry are welcome. Keep it fun and respectful.")

    def test_authentication_and_followed_team_access_apply_to_static_rules(self):
        self.remove_rules_table()
        url = "/v1/community/rules?team_id=6"
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.request("GET", url, self.token_b).status_code, 403)
        # 다른 팔로우 팀도 안내를 읽을 수 있고, 팔로우를 해제하면 조회 권한을 잃어요.
        self.execute("INSERT INTO user_following_teams VALUES (%s,8,6,1)", (self.b,))
        self.assertEqual(self.request("GET", url, self.token_b).status_code, 200)
        self.execute("UPDATE users SET favorite_team_id=6 WHERE user_id=%s", (self.b,))
        self.assertEqual(self.request("GET", url, self.token_b).status_code, 200)
        self.assertEqual(self.request("GET", "/v1/community/rules?team_id=503", self.token_b).status_code, 200)
        self.execute("DELETE FROM user_following_teams WHERE user_id=%s AND team_id=503", (self.b,))
        self.assertEqual(self.request("GET", "/v1/community/rules?team_id=503", self.token_b).status_code, 403)

    def test_language_is_not_required_and_admin_editing_is_not_exposed(self):
        self.remove_rules_table()
        self.assertEqual(self.request("GET", "/v1/community/rules", params={"team_id": 6}).status_code, 200)
        # 운영자도 API로 코드에 있는 문구를 덮어쓰지 못해요.
        with patch.dict("os.environ", {"COMMUNITY_ADMIN_USER_IDS": str(self.a)}):
            for method in ("GET", "PUT"):
                response = self.request(method, "/v1/admin/community/rules?language=ko", json={"body": "Replacement"})
                self.assertEqual(response.status_code, 404)
        paths = self.client.get("/openapi.json").json()["paths"]
        self.assertNotIn("/v1/admin/community/rules", paths)
        self.assertIn("/v1/community/rules", paths)
