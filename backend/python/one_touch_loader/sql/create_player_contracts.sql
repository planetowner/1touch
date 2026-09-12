-- 현재 계약 날짜만 보관해요. 재계약 이력·실제 소속 기간·남은 연수는 복제하지 않아요.
-- 계약이 끝난 뒤 FA 공백을 거쳐 입단할 수 있어 이적 날짜로 계약 종료일을 채우지 않아요.
CREATE TABLE player_contracts (
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  -- 날짜가 달라도 같은 계약일 수 있어 공급자가 연결한 이적 ID를 따로 보존해요.
  transfer_id BIGINT UNSIGNED NULL,
  PRIMARY KEY (team_id, player_id),
  KEY idx_player_contracts_player (player_id),
  CONSTRAINT fk_player_contracts_team FOREIGN KEY (team_id)
    REFERENCES teams (team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_player_contracts_player FOREIGN KEY (player_id)
    REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_player_contracts_transfer FOREIGN KEY (transfer_id)
    REFERENCES transfers (transfer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_player_contracts_dates CHECK (start_date IS NULL OR end_date IS NULL OR start_date <= end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
