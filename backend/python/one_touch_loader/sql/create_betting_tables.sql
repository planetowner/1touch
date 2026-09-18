-- 기존 회원·경기·예측 데이터는 유지해요. 포인트는 회원의 첫 초기화 요청에서 한 번 지급해요.
CREATE TABLE IF NOT EXISTS user_point_wallets (
    user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    balance BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT chk_point_wallet_balance CHECK (balance >= 0),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 한 회원의 한 경기 참여는 한 행이에요. 시작 전 변경·취소·재참여는 revision으로 구분해요.
CREATE TABLE IF NOT EXISTS fixture_bets (
    bet_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    fixture_id BIGINT UNSIGNED NOT NULL,
    prediction_run_id CHAR(64) CHARACTER SET ascii NOT NULL,
    outcome ENUM('home_win','draw','away_win') NOT NULL,
    stake BIGINT NOT NULL,
    probability DECIMAL(20,18) NOT NULL,
    potential_return BIGINT NOT NULL,
    status ENUM('open','cancelled','won','lost','refunded') NOT NULL,
    revision INT UNSIGNED NOT NULL,
    payout BIGINT NOT NULL DEFAULT 0,
    settlement_reason VARCHAR(50) NULL,
    settled_home_score SMALLINT UNSIGNED NULL,
    settled_away_score SMALLINT UNSIGNED NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    settled_at DATETIME(6) NULL,
    UNIQUE KEY one_bet_per_user_fixture (user_id, fixture_id),
    KEY pending_fixture_bets (status, fixture_id, bet_id),
    CONSTRAINT chk_bet_stake CHECK (stake >= 10 AND MOD(stake, 10) = 0),
    CONSTRAINT chk_bet_probability CHECK (probability > 0 AND probability <= 1),
    CONSTRAINT chk_bet_return CHECK (potential_return >= stake AND payout >= 0),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id),
    FOREIGN KEY (prediction_run_id) REFERENCES probability_runs(run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 잔액과 원장을 같은 트랜잭션에서 바꿔요. 요청 ID는 재전송으로 이중 차감되는 것을 막아요.
CREATE TABLE IF NOT EXISTS user_point_entries (
    entry_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    bet_id BIGINT UNSIGNED NULL,
    request_id VARCHAR(64) CHARACTER SET ascii NOT NULL,
    request_hash CHAR(64) CHARACTER SET ascii NOT NULL,
    kind ENUM('welcome','bet_place','bet_change','bet_cancel','bet_win','bet_loss','bet_refund') NOT NULL,
    amount BIGINT NOT NULL,
    balance_after BIGINT NOT NULL,
    bet_revision INT UNSIGNED NULL,
    created_at DATETIME(6) NOT NULL,
    UNIQUE KEY one_point_request (user_id, request_id),
    KEY user_point_history (user_id, entry_id),
    CONSTRAINT chk_point_entry_balance CHECK (balance_after >= 0),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (bet_id) REFERENCES fixture_bets(bet_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
