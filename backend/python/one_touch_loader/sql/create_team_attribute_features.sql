SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `team_attribute_features` (
  `season_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,

-- 집계 시점의 시즌 경기당 승점이에요. 학습 목표와 통계 입력이 따로 갱신되지 않게 함께 보관해요.
  `points_per_match` decimal(10,6) NOT NULL,

-- 각 영역의 필수 통계가 함께 제공된 경기만 써요. 38경기 중 30경기에 있으면 그 30경기로 집계해요.
-- 제공된 0은 포함하고, 공통 제공 경기가 없거나 비율의 분모가 0이면 NULL로 남겨요.
-- 점유와 빌드업
  `ball_possession_avg` decimal(12,6) NULL,
  `ball_safe_per_match` decimal(12,6) NULL,
  `passes_per_match` decimal(12,6) NULL,
  `pass_accuracy` decimal(12,6) NULL,

-- 공격 위협
  `dangerous_attacks_per_match` decimal(12,6) NULL,
  `total_crosses_per_match` decimal(12,6) NULL,
  `cross_accuracy` decimal(12,6) NULL,
  `dribble_attempts_per_match` decimal(12,6) NULL,
  `dribble_success_rate` decimal(12,6) NULL,

-- 기회 창출
  `corners_per_match` decimal(12,6) NULL,
  `key_passes_per_match` decimal(12,6) NULL,
  `big_chances_created_per_match` decimal(12,6) NULL,

-- 마무리
  `shots_insidebox_per_match` decimal(12,6) NULL,
  `conversion_rate` decimal(12,6) NULL,
  `shots_on_target_per_match` decimal(12,6) NULL,
  `shot_accuracy` decimal(12,6) NULL,

-- 수비
-- 이 팀이 상대에게 허용한 통계예요.
-- 원본 값이 낮을수록 좋으므로 학습할 때 이 특성의 z-score 부호를 바꿔요.
  `goals_against_per_match` decimal(12,6) NULL,
  `shots_on_target_against_per_match` decimal(12,6) NULL,
  `shots_insidebox_against_per_match` decimal(12,6) NULL,
  `big_chances_against_per_match` decimal(12,6) NULL,
  `dangerous_attacks_against_per_match` decimal(12,6) NULL,

  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`team_id`, `season_id`),
  KEY `idx_team_attribute_features_season` (`season_id`),
  CONSTRAINT `fk_team_attribute_features_team_season`
    FOREIGN KEY (`team_id`, `season_id`) REFERENCES `team_seasons` (`team_id`, `season_id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
