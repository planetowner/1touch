-- 과거 기준 표본은 유지하고, 평가 결과만 중반 전 1경기부터 저장할 수 있게 바꿔요.
ALTER TABLE player_rating_scores
  DROP CHECK chk_player_rating_score_matches,
  ADD CONSTRAINT chk_player_rating_score_matches CHECK (rated_matches >= 1);
