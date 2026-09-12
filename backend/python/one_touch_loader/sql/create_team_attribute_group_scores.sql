SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `team_attribute_group_scores` (
  `model_id` bigint unsigned NOT NULL,
  `season_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,
  `attribute_group` varchar(100) NOT NULL,

-- 필수 항목을 계산할 수 없는 팀·시즌·영역은 점수 행을 저장하지 않아요.
-- clamp(50 + 15 * SUM(feature_z * weight), 5, 95)로 환산한 최종 점수예요.
-- 중간값에서 다시 환산하면 반올림 결과가 달라질 수 있어 최종값을 그대로 저장해요.
  `display_score_0_100` decimal(8,4) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`model_id`, `team_id`, `season_id`, `attribute_group`),
  KEY `idx_team_attribute_group_scores_season` (`season_id`),
  KEY `idx_team_attribute_group_scores_team_season` (`team_id`, `season_id`),
  CONSTRAINT `fk_team_attribute_group_scores_model`
    FOREIGN KEY (`model_id`) REFERENCES `team_attribute_regression_models` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_team_attribute_group_scores_team_season`
    FOREIGN KEY (`team_id`, `season_id`) REFERENCES `team_seasons` (`team_id`, `season_id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
