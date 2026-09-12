-- 실행기는 확인한 두 빈 테이블만 교체하도록 사전 검증하고 백업해요.
DROP TABLE team_transfers;
DROP TABLE transfer_windows;

-- 같은 이동도 출발·도착 리그의 등록 기간이 달라 이적 행에 window_id를 붙이지 않아요.
CREATE TABLE transfer_windows (
  season_id BIGINT UNSIGNED NOT NULL,
  window_name ENUM('summer','winter') NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  PRIMARY KEY (season_id, window_name),
  CONSTRAINT fk_transfer_windows_season FOREIGN KEY (season_id) REFERENCES seasons (season_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_transfer_windows_dates CHECK (start_date <= end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
