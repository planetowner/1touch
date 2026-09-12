SET NAMES utf8mb4;

-- 백업·적용 전후 대조를 포함한 run_team_attributes_minimal_migration.ps1로 실행해요.
-- 뷰가 참조하는 대회 ID를 제거한 뒤, 공통 생성 SQL로 뷰를 다시 만들어요.
DROP VIEW v_team_attribute_display_scores;

-- 집계값은 학습과 현재 시즌 점수 계산에 함께 써서 training을 이름에서 빼요.
-- 팀·시즌 관계를 기본 키로 쓰고, 대회와 순위표의 중복 정보는 제거해요.
ALTER TABLE team_attribute_training_features
  DROP PRIMARY KEY,
  DROP COLUMN id,
  DROP COLUMN competition_id,
  DROP COLUMN matches_played,
  DROP COLUMN points,
  DROP COLUMN created_at,
  DROP INDEX uq_team_attribute_training_features_scope,
  DROP INDEX idx_team_attribute_training_features_competition_season,
  DROP INDEX idx_team_attribute_training_features_team,
  RENAME INDEX idx_team_attribute_training_features_season TO idx_team_attribute_features_season,
  ADD PRIMARY KEY (team_id, season_id),
  ADD CONSTRAINT fk_team_attribute_features_team_season
    FOREIGN KEY (team_id, season_id) REFERENCES team_seasons (team_id, season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  RENAME TO team_attribute_features;

-- 원본 계수와 실제 사용한 가중치는 보존하고, 계산 가능한 양수 계수만 제거해요.
ALTER TABLE team_attribute_regression_weights
  DROP PRIMARY KEY,
  DROP COLUMN id,
  DROP COLUMN positive_coefficient,
  DROP COLUMN created_at,
  DROP INDEX uq_team_attribute_regression_weight,
  DROP INDEX idx_team_attribute_regression_weights_group,
  ADD PRIMARY KEY (model_id, attribute_group, feature_name);

-- 모델 FK를 받쳐 주는 새 기본 키를 만든 뒤 중복 인덱스를 제거해요.
ALTER TABLE team_attribute_regression_weights
  DROP INDEX idx_team_attribute_regression_weights_model;

-- 기존 최종 점수와 갱신 시각은 그대로 보존해요. 원시 점수에서 다시 계산하지 않아요.
-- 삭제되는 기여도 JSON과 모델 notes 원문은 실행 스크립트의 SQL 백업에 남아요.
ALTER TABLE team_attribute_group_scores
  DROP PRIMARY KEY,
  DROP COLUMN id,
  DROP COLUMN competition_id,
  DROP COLUMN raw_score,
  DROP COLUMN feature_contributions_json,
  DROP COLUMN created_at,
  DROP INDEX uq_team_attribute_group_scores_scope,
  DROP INDEX idx_team_attribute_group_scores_competition_season,
  DROP INDEX idx_team_attribute_group_scores_team,
  DROP INDEX idx_team_attribute_group_scores_group,
  ADD PRIMARY KEY (model_id, team_id, season_id, attribute_group),
  ADD KEY idx_team_attribute_group_scores_season (season_id),
  ADD KEY idx_team_attribute_group_scores_team_season (team_id, season_id),
  ADD CONSTRAINT fk_team_attribute_group_scores_team_season
    FOREIGN KEY (team_id, season_id) REFERENCES team_seasons (team_id, season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE team_attribute_group_scores
  DROP INDEX idx_team_attribute_group_scores_model;

-- 모델 설정과 가중치의 중복 사본을 빼고 영역별 행 수·절편·학습 R²를 보존해요.
UPDATE team_attribute_regression_models
SET notes = JSON_REMOVE(notes,
  '$.description',
  '$.feature_groups',
  '$.lower_is_better_features',
  '$.group_results.possession_build_up.features',
  '$.group_results.possession_build_up.coefficients',
  '$.group_results.possession_build_up.positive_coefficients',
  '$.group_results.possession_build_up.weights',
  '$.group_results.possession_build_up.lower_is_better_features',
  '$.group_results.attacking_threat.features',
  '$.group_results.attacking_threat.coefficients',
  '$.group_results.attacking_threat.positive_coefficients',
  '$.group_results.attacking_threat.weights',
  '$.group_results.attacking_threat.lower_is_better_features',
  '$.group_results.chance_creation.features',
  '$.group_results.chance_creation.coefficients',
  '$.group_results.chance_creation.positive_coefficients',
  '$.group_results.chance_creation.weights',
  '$.group_results.chance_creation.lower_is_better_features',
  '$.group_results.finishing.features',
  '$.group_results.finishing.coefficients',
  '$.group_results.finishing.positive_coefficients',
  '$.group_results.finishing.weights',
  '$.group_results.finishing.lower_is_better_features',
  '$.group_results.defending.features',
  '$.group_results.defending.coefficients',
  '$.group_results.defending.positive_coefficients',
  '$.group_results.defending.weights',
  '$.group_results.defending.lower_is_better_features'
);
