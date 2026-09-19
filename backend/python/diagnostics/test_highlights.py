"""새 경기 자동 교체·국가 제한·실제 채널의 예외를 운영 DB 없이 확인해요."""
from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from one_touch_loader.core.highlights import (
    load_catalog, match_video, normalize_video, select_latest_matches,
)
from one_touch_loader.core.highlight_fixtures import from_dfb_html
from one_touch_loader.api.schemas.highlights import TeamHighlightsResponse, FixtureHighlightsResponse

# 파일 읽기와 순수 함수만 시험해요. 실제 연결 풀은 만들지 않아요.
with patch("mysql.connector.pooling.MySQLConnectionPool"):
    from one_touch_loader.loaders import highlights_loader as loader
    from one_touch_loader.api.repos import highlights_repo
    from one_touch_loader.api.routes import teams as team_routes
    from one_touch_loader.api.routes import fixtures as fixture_routes

SAMPLE = json.loads((Path(__file__).parent / "fixtures/highlights-sample.json").read_text(encoding="utf-8"))
CATALOG = load_catalog()


def sample_video(video_id="9vaPWVvl5Y8"):
    return normalize_video(deepcopy(SAMPLE["videos"][video_id]))


def candidate(key, day, *, source="club", extended=False, restriction=None, publish_day=None):
    return {
        **sample_video(), "video_id": key, "source_type": source, "is_extended": extended,
        "published_at": f"2026-09-{publish_day or day:02d}T23:00:00Z",
        "region_restriction": restriction or {},
        "match": {**SAMPLE["matches"]["9vaPWVvl5Y8"], "match_key": f"sportmonks:{day}",
                  "starting_at": f"2026-09-{day:02d}T18:00:00Z"},
    }


class HighlightSelectionTests(unittest.TestCase):
    def test_new_match_replaces_oldest_not_reupload_of_old_match(self):
        cached = [candidate("a", 1), candidate("b", 3), candidate("c", 5)]
        self.assertEqual([v["video_id"] for v in select_latest_matches(cached, "KR")], ["c", "b", "a"])
        cached += [candidate("old-reupload", 1, publish_day=9), candidate("new", 8)]
        self.assertEqual([v["video_id"] for v in select_latest_matches(cached, "KR")], ["new", "c", "b"])

    def test_country_first_then_club_then_regular_with_one_per_match(self):
        videos = [candidate("club", 8, restriction={"blocked": ["KR"]}),
                  candidate("extended", 8, extended=True), candidate("league", 8, source="competition"),
                  candidate("allowed-US", 9, restriction={"allowed": ["US"]}), candidate("old", 3)]
        self.assertEqual([v["video_id"] for v in select_latest_matches(videos, "kr")], ["extended", "old"])
        self.assertEqual([v["video_id"] for v in select_latest_matches(videos, "US")], ["allowed-US", "club", "old"])
        videos[1]["region_restriction"] = {"allowed": []}
        self.assertEqual(select_latest_matches(videos, "KR")[0]["video_id"], "league")

    def test_under_three_and_no_playable_video_are_not_padded(self):
        self.assertEqual(len(select_latest_matches([candidate("one", 1)], "JP")), 1)
        self.assertEqual(select_latest_matches([candidate("none", 1, restriction={"allowed": []})], "JP"), [])

    def test_external_playback_leaves_country_restrictions_to_youtube(self):
        videos = [candidate("club", 8, restriction={"allowed": ["GB"]}),
                  candidate("competition", 8, source="competition")]
        self.assertEqual(select_latest_matches(videos, None)[0]["video_id"], "club")
        self.assertEqual(select_latest_matches(videos, "KR")[0]["video_id"], "competition")

    def test_actual_description_wording_does_not_exclude_match_highlights(self):
        for vid in ("9vaPWVvl5Y8", "xoungdAL15U", "yV9AugsrnXM"):
            with self.subTest(video=vid):
                video = sample_video(vid)
                source = next(s for s in CATALOG["clubs"] if s["channel_id"] == video["channel_id"])
                match = SAMPLE["matches"][vid]
                matched, reason = match_video(video, [match], source, CATALOG["aliases"], {vid})
                self.assertEqual(reason, "matched")
                self.assertEqual(matched, match)

    def test_actual_radio_press_youth_and_goal_montage_not_match_highlights(self):
        for vid in ("fF6X-FYLcgE", "XxRbZB4ZoGg", "LQ0Nb6oo6CE", "VKeBylwZvfM", "3WdnDM0JiSo"):
            with self.subTest(video=vid):
                video = sample_video(vid)
                if video is None:
                    continue
                source = next(s for s in CATALOG["clubs"] if s["channel_id"] == video["channel_id"])
                matched, reason = match_video(video, list(SAMPLE["matches"].values()), source, CATALOG["aliases"], set())
                self.assertIsNone(matched, vid)
                self.assertNotEqual(reason, "matched")

    def test_70_second_landscape_valid_but_vertical_and_unlisted_excluded(self):
        self.assertIsNotNone(sample_video("wAUcoEMMbkA"))
        self.assertIsNone(sample_video("1janmXLKBrU"))
        self.assertIsNone(sample_video("HpeCCugYpsU"))

    def test_ambiguous_second_fixture_and_wrong_channel_not_guessed(self):
        video = sample_video()
        source = next(s for s in CATALOG["clubs"] if s["channel_id"] == video["channel_id"])
        match = SAMPLE["matches"][video["video_id"]]
        second = {**match, "match_key": "sportmonks:duplicate"}
        result, reason = match_video(video, [match, second], source, CATALOG["aliases"], set())
        self.assertIsNone(result)
        self.assertEqual(reason, "ambiguous_match")
        result, reason = match_video(video, [match], {**source, "channel_id": "fan-channel"}, {}, {video["video_id"]})
        self.assertEqual(reason, "different_channel")

    def test_dfb_completed_external_fixture_and_german_timezone(self):
        document = '''<div class="c-MatchTable-body"><div class="c-MatchTable-row">
          <span id="match_123"></span><div class="c-MatchTable-description">Mi, 02.09.2026 20:45</div>
          <div class="c-MatchTable-team--home"><a>VfL Osnabrück</a></div>
          <div class="c-MatchTable-team--away"><a>FC Bayern München</a></div>
          <div class="c-MatchTable-score"><a href="https://datencenter.dfb.de/matches/123">1:4</a></div>
        </div></div>'''
        source = CATALOG["external_fixture_sources"][0]
        match, = from_dfb_html(document, source, CATALOG["dfb_team_names"])
        self.assertIsNone(match["fixture_id"])
        self.assertEqual(match["starting_at"], "2026-09-02T18:45:00Z")
        self.assertEqual(match["away"]["team_id"], 503)
        self.assertEqual(from_dfb_html(document.replace("1:4", "-:-"), source, CATALOG["dfb_team_names"]), [])

    def test_hamburg_eimsbuettel_is_not_confused_with_hamburger_sv(self):
        video = sample_video("lEEKCo2v1ds")
        source = next(s for s in CATALOG["clubs"] if s["team_id"] == 68)
        result, reason = match_video(video, [SAMPLE["matches"]["hebc"], SAMPLE["matches"]["hsv"]],
                                     source, CATALOG["aliases"], set())
        self.assertEqual(reason, "matched")
        self.assertEqual(result["match_key"], "dfb:2418311")

    def test_two_legs_resolved_by_title_order_without_manual_video_id(self):
        video = sample_video("7-7cVqRoVkc")
        source = next(s for s in CATALOG["clubs"] if s["team_id"] == 78)
        fixtures = [SAMPLE["matches"][key] for key in ("sportmonks:19788635", "sportmonks:19788588")]
        result, reason = match_video(video, fixtures, source, CATALOG["aliases"], set())
        self.assertEqual(reason, "matched")
        self.assertEqual(result["match_key"], "sportmonks:19788588")


class CollectionTests(unittest.TestCase):
    def test_curated_playlist_paginates_past_old_first_page(self):
        client = loader.YouTubeClient.__new__(loader.YouTubeClient)
        old = {"contentDetails": {"videoPublishedAt": "2025-01-01T00:00:00Z", "videoId": "old"}}
        new = {"contentDetails": {"videoPublishedAt": "2026-09-10T00:00:00Z", "videoId": "new"}}
        client.get = Mock(side_effect=[{"items": [old], "nextPageToken": "next"}, {"items": [new]}])
        self.assertEqual(client.playlist("curated", "2026-07-01"), [new])
        self.assertEqual(client.get.call_count, 2)
        client.get = Mock(return_value={"items": [old], "nextPageToken": "next"})
        self.assertEqual(client.playlist("uploads", "2026-07-01", uploads=True), [])
        self.assertEqual(client.get.call_count, 1)

    def test_incremental_refresh_rechecks_saved_and_late_playlist_videos(self):
        video = sample_video()
        source = next(s for s in CATALOG["clubs"] if s["channel_id"] == video["channel_id"])
        source = {**source, "playlists": [{"playlist_id": "curated", "name": "Highlights"}]}
        youtube = Mock()
        youtube.playlist.side_effect = [[], [{"contentDetails": {"videoId": video["video_id"]}}]]
        youtube.videos.return_value = [video]
        candidates, _, _ = loader.collect_candidates([source], {**CATALOG, "competitions": []},
            [SAMPLE["matches"][video["video_id"]]], youtube, since="2026-09-17T00:00:00Z",
            saved_ids={video["channel_id"]: {"old-saved"}})
        self.assertEqual(youtube.videos.call_args.args[0], {video["video_id"], "old-saved"})
        self.assertEqual(youtube.playlist.call_args_list[1].args, ("curated", CATALOG["from_date"]))
        self.assertEqual(len(candidates[source["team_id"]]), 1)

    def test_request_failure_does_not_replace_existing_cache(self):
        with patch.object(loader, "load_saved_sources", return_value=(None, {})), \
             patch.object(loader, "collect_matches", side_effect=RuntimeError("provider unavailable")), \
             patch.object(loader, "save_candidates") as save:
            with self.assertRaisesRegex(RuntimeError, "provider unavailable"):
                loader.refresh_highlights([CATALOG["clubs"][0]["team_id"]], apply=True)
            save.assert_not_called()

    def test_check_mode_never_saves_and_apply_waits_until_complete(self):
        club = CATALOG["clubs"][0]
        candidates = {club["team_id"]: [candidate("new", 8)]}
        with tempfile.TemporaryDirectory() as folder, \
             patch.object(loader, "load_saved_sources", return_value=(None, {})), \
             patch.object(loader, "collect_matches", return_value=[]), \
             patch.object(loader, "YouTubeClient"), \
             patch.object(loader, "collect_candidates", return_value=(candidates, {}, [])), \
             patch.object(loader, "save_candidates") as save:
            loader.refresh_highlights([club["team_id"]], report_dir=folder)
            save.assert_not_called()
            loader.refresh_highlights([club["team_id"]], report_dir=folder, apply=True)
            self.assertEqual(save.call_count, 1)
            self.assertEqual(save.call_args.args[1], candidates)


class HighlightAPITests(unittest.TestCase):
    def test_fixture_query_uses_exact_id_and_shared_country_selection(self):
        fixture_id = 19722166
        values = [candidate("blocked-club", 13, restriction={"blocked": ["KR"]}),
                  candidate("extended", 13, extended=True),
                  candidate("regular", 13), candidate("competition", 13, source="competition")]
        rows = [{**v, "fixture_id": fixture_id, "match_key": f"sportmonks:{fixture_id}",
                 "title": v["title"] + (" Extended" if v["is_extended"] else ""),
                 "starting_at": v["match"]["starting_at"], "checked_at": datetime(2026, 9, 19),
                 "home_team_id": 14, "away_team_id": 9, "home_name": "Manchester United",
                 "away_name": "Manchester City", "season_name": "2026/2027",
                 "competition_id": 8, "competition_name": "Premier League"} for v in values]
        with patch.object(highlights_repo, "fetch_all_dict", return_value=rows) as fetch:
            response = FixtureHighlightsResponse.model_validate(
                highlights_repo.get_fixture_highlights(fixture_id, "kr"))
        sql, params = fetch.call_args.args
        self.assertIn("WHERE m.fixture_id=%s", sql)
        self.assertNotIn("WHERE th.team_id=%s", sql)
        self.assertEqual(params, (fixture_id,))
        self.assertEqual(response.viewer_country, "KR")
        self.assertEqual([v.video_id for v in response.items], ["regular"])
        self.assertEqual(response.items[0].match.fixture_id, fixture_id)

    def test_fixture_without_video_returns_empty(self):
        with patch.object(highlights_repo, "fetch_all_dict", return_value=[]):
            response = highlights_repo.get_fixture_highlights(19722166, "KR")
        self.assertEqual(response["items"], [])
        self.assertIsNone(response["updated_at"])

    def test_fixture_endpoint_country_auth_and_missing_fixture(self):
        app = FastAPI()
        app.include_router(fixture_routes.router, prefix="/v1")
        path = "/v1/fixtures/19722166/highlights"
        with TestClient(app) as client:
            self.assertEqual(client.get(path + "?viewer_country=KR").status_code, 401)
        app.dependency_overrides[fixture_routes.get_user_id] = lambda: 1
        payload = {"fixture_id": 19722166, "viewer_country": "KR", "updated_at": None, "items": []}
        with TestClient(app) as client, \
             patch.object(fixture_routes, "get_fixture", return_value={"fixture_id": 19722166}) as fixture, \
             patch.object(fixture_routes, "get_fixture_highlights", return_value=payload) as highlights:
            self.assertEqual(client.get(path + "?viewer_country=KOR").status_code, 422)
            response = client.get(path + "?viewer_country=KR")
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json(), payload)
            highlights.assert_called_once_with(19722166, "KR")
            fixture.return_value = None
            self.assertEqual(client.get(path + "?viewer_country=KR").status_code, 404)
            highlights.assert_called_once()

    def test_fixture_endpoint_allows_external_playback_without_country(self):
        app = FastAPI()
        app.include_router(fixture_routes.router, prefix="/v1")
        app.dependency_overrides[fixture_routes.get_user_id] = lambda: 1
        payload = {"fixture_id": 19722166, "viewer_country": None, "updated_at": None,
                   "items": [candidate("official", 13)]}
        with TestClient(app) as client, \
             patch.object(fixture_routes, "get_fixture", return_value={"fixture_id": 19722166}), \
             patch.object(fixture_routes, "get_fixture_highlights", return_value=payload) as highlights:
            response = client.get("/v1/fixtures/19722166/highlights")
            self.assertEqual(response.status_code, 200, response.text)
            self.assertIsNone(response.json()["viewer_country"])
            self.assertNotIn("region_restriction", response.json()["items"][0])
            highlights.assert_called_once_with(19722166, None)

    def test_repository_reads_json_and_uses_shared_selector(self):
        values = [candidate("a", 1), candidate("b", 3), candidate("c", 5), candidate("new", 8)]
        rows = []
        for v in values:
            rows.append({**v, 'fixture_id':None,'match_key':v['match']['match_key'],
                         'external_record':json.dumps({k:val for k,val in v['match'].items() if k not in ('score','penalty_shootout')}),
                         'starting_at':v['match']['starting_at'], 'region_restriction':json.dumps(v['region_restriction']),
                         'checked_at':datetime(2026,9,17)})
        with patch.object(highlights_repo, "fetch_all_dict", return_value=rows):
            response = TeamHighlightsResponse.model_validate(highlights_repo.get_team_highlights(68, "kr"))
        self.assertEqual([v.video_id for v in response.items], ["new", "c", "b"])
        self.assertEqual(response.updated_at.tzinfo, timezone.utc)

    def test_endpoint_requires_country_and_excludes_internal_metadata(self):
        app = FastAPI()
        app.include_router(team_routes.router, prefix="/v1")
        app.dependency_overrides[team_routes.get_user_id] = lambda: 1
        payload = {"team_id": 68, "viewer_country": "KR", "updated_at": None, "items": [candidate("new", 8)]}
        with TestClient(app) as client, patch.object(team_routes, "get_team", return_value={"team_id": 68}), \
             patch.object(team_routes, "get_team_highlights", return_value=payload):
            self.assertEqual(client.get("/v1/teams/68/highlights").status_code, 422)
            response = client.get("/v1/teams/68/highlights?viewer_country=KR")
            self.assertEqual(response.status_code, 200, response.text)
            self.assertNotIn("region_restriction", response.json()["items"][0])
            self.assertNotIn("description", response.json()["items"][0])
            self.assertNotIn("score", response.json()["items"][0]["match"])
            self.assertNotIn("penalty_shootout", response.json()["items"][0]["match"])


if __name__ == "__main__":
    unittest.main()
