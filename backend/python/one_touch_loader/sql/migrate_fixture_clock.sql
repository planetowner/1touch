-- 기존 경기·통계 테이블을 유지하고 공급자가 관측한 경기 시계만 추가해요.
CREATE TABLE fixture_clock (
  fixture_id BIGINT UNSIGNED NOT NULL,
  period_type_id INT UNSIGNED NULL,
  counts_from SMALLINT UNSIGNED NULL,
  period_length SMALLINT UNSIGNED NULL,
  minutes SMALLINT UNSIGNED NULL,
  seconds TINYINT UNSIGNED NULL,
  ticking BOOLEAN NOT NULL,
  time_added SMALLINT UNSIGNED NULL,
  sampled_at DATETIME(6) NOT NULL,
  PRIMARY KEY (fixture_id),
  CONSTRAINT fk_fixture_clock_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_fixture_clock_seconds CHECK (seconds IS NULL OR seconds < 60)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
