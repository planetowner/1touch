-- 기존 고정 기준 테이블을 누적 비교 표본으로 전환해요. 실행 후 전체 재계산이 필요해요.
-- API와 경기 적재 작업을 멈춘 상태에서 한 번 실행해요. 기존 행은 재계산 전까지 보존해요.
ALTER TABLE player_rating_references
    CHANGE COLUMN frozen_at updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- 현재 시즌의 1경기 기록도 비교 집단에 포함해요. 시즌별 자격은 공통 적재 함수에서 판단해요.
ALTER TABLE player_rating_reference_samples
    DROP CHECK chk_player_rating_reference_matches,
    ADD CONSTRAINT chk_player_rating_reference_matches CHECK (rated_matches >= 1);
