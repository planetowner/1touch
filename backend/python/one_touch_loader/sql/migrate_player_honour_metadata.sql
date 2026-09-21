-- 수집 대상 밖의 과거 대회도 표시할 수 있도록 공급자가 제공한 이름만 보존해요.
-- 운영 적용 전 player_team_honours를 백업해요. 미제공 정보는 NULL로 유지해요.
ALTER TABLE player_team_honours
  ADD COLUMN team_name VARCHAR(160) NULL,
  ADD COLUMN team_image_path VARCHAR(512) NULL,
  ADD COLUMN competition_name VARCHAR(120) NULL,
  ADD COLUMN season_name VARCHAR(120) NULL;
