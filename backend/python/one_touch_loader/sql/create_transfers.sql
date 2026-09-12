CREATE TABLE transfer_types (
  type_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 확정 이적 원문을 저장하고 1군 분류는 Club History에서 적용해요. 표시 정보·이적시장 ID는 복제하지 않아요.
CREATE TABLE transfers (
  transfer_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  from_team_id BIGINT UNSIGNED NULL,
  to_team_id BIGINT UNSIGNED NULL,
  type_id BIGINT UNSIGNED NOT NULL,
  amount BIGINT UNSIGNED NULL,
  transfer_date DATE NOT NULL,
  PRIMARY KEY (transfer_id),
  KEY idx_transfers_player_date (player_id, transfer_date),
  KEY idx_transfers_from_date (from_team_id, transfer_date),
  KEY idx_transfers_to_date (to_team_id, transfer_date),
  CONSTRAINT fk_transfers_player FOREIGN KEY (player_id) REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_transfers_from FOREIGN KEY (from_team_id) REFERENCES teams (team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_transfers_to FOREIGN KEY (to_team_id) REFERENCES teams (team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_transfers_type FOREIGN KEY (type_id) REFERENCES transfer_types (type_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
