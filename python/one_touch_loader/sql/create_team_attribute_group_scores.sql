SET NAMES utf8mb4;

DROP TABLE IF EXISTS `team_attribute_group_scores`;

CREATE TABLE `team_attribute_group_scores` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,

  `model_id` bigint unsigned NOT NULL,

  `league_id` bigint unsigned NOT NULL,
  `season_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,

  `attribute_group` varchar(100) NOT NULL,

  -- Internal UI attribute score.
  -- Formula:
  --   SUM(feature_z * non_negative_normalized_weight)
  `raw_score` decimal(14,8) NOT NULL,

  -- UI-ready radar / hexagon score.
  -- Formula:
  --   clamp(50 + 15 * raw_score, 5, 95)
  `display_score_0_100` decimal(8,4) NOT NULL,

  -- Debug / explanation payload.
  `feature_contributions_json` json NULL,

  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  UNIQUE KEY `uq_team_attribute_group_scores_scope`
    (`model_id`, `league_id`, `season_id`, `team_id`, `attribute_group`),

  KEY `idx_team_attribute_group_scores_model` (`model_id`),
  KEY `idx_team_attribute_group_scores_league_season` (`league_id`, `season_id`),
  KEY `idx_team_attribute_group_scores_team` (`team_id`),
  KEY `idx_team_attribute_group_scores_group` (`attribute_group`),

  CONSTRAINT `fk_team_attribute_group_scores_model`
    FOREIGN KEY (`model_id`)
    REFERENCES `team_attribute_regression_models` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;