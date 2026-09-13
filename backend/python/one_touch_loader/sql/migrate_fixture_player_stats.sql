-- 기존 선수 프로필 포지션은 유지하고, 해당 경기의 출전 포지션을 별도로 저장해요.
-- 경기 포지션 24~27은 프로필의 세부 포지션과 다른 분류라 그 테이블에 FK를 걸지 않아요.
ALTER TABLE fixture_lineups ADD COLUMN match_position_id INT NULL;

CREATE TABLE fixture_player_stats (
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  stat_type_id INT NOT NULL,
  stat_value DECIMAL(12,4) NOT NULL,
  PRIMARY KEY (fixture_id, team_id, player_id, stat_type_id),
  CONSTRAINT fk_fixture_player_stats_lineup
    FOREIGN KEY (fixture_id, team_id, player_id)
    REFERENCES fixture_lineups (fixture_id, team_id, player_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
