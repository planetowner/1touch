-- Understat가 Alarcón·Youssif·García Pascual·Everton에게 각각 ID 두 개를 부여했어요.
-- 컬럼·PK·FK·기존 데이터는 그대로 두고 선수별 공급자 ID의 개수 제한만 해제해요.
-- Capology의 일대일 검사는 기존 적재 코드에서, Understat의 확인된 예외는 매핑 코드에서 유지해요.
ALTER TABLE player_external_ids
  ADD INDEX idx_player_external_player_provider (player_id, provider),
  DROP INDEX uq_player_external_provider;
