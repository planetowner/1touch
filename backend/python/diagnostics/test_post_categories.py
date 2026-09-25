"""팬아트 분류가 조회·작성·수정·초안에서 같은 값으로 전달되는지 확인해요."""
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

# API 계약만 검사하므로 운영 DB 연결은 열지 않아요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.api.routes import posts


class PostCategoryTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(posts.router, prefix="/v1")
        app.dependency_overrides[posts.get_user_id] = lambda: 1
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def test_fanart_filter_reaches_the_repository(self):
        with patch.object(posts.posts_repo, "list_posts", return_value=[]) as load:
            response = self.client.get("/v1/posts", params={"team_id": 9, "category": "fanart"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(load.call_args.args[2], "fanart")

    def test_fanart_is_accepted_for_posts_and_drafts(self):
        for path in ("posts", "post-drafts"):
            with self.subTest(path=path), \
                    patch.object(posts.posts_repo, "create_post", return_value=42) as create, \
                    patch.object(posts.posts_repo, "update_post") as update, \
                    patch.object(posts.posts_repo, "get_draft", return_value={"post_id": 42, "category": "fanart"}):
                body = {"category": "fanart", "title": "Drawing", "body": "My team"}
                response = self.client.post(f"/v1/{path}", json={"team_id": 9, **body})
                self.assertEqual(response.status_code, 201, response.text)
                self.assertEqual(create.call_args.kwargs["category"], "fanart")
                response = self.client.put(f"/v1/{path}/42", json=body)
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(update.call_args.kwargs["category"], "fanart")

    def test_all_is_only_a_tab_and_not_a_stored_category(self):
        with patch.object(posts.posts_repo, "create_post") as create:
            response = self.client.post("/v1/posts", json={
                "team_id": 9, "category": "all", "title": "Invalid category", "body": "Body",
            })
        self.assertEqual(response.status_code, 422)
        create.assert_not_called()


if __name__ == "__main__":
    unittest.main()
