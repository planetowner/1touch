SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `team_attribute_training_features` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,

  `league_id` bigint unsigned NOT NULL,
  `season_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,

  `matches_played` int NOT NULL,
  `points` int NOT NULL,
  `points_per_match` decimal(10,6) NOT NULL,

  -- Possession & Build-up
  `ball_possession_avg` decimal(12,6) NULL,
  `ball_safe_per_match` decimal(12,6) NULL,
  `passes_per_match` decimal(12,6) NULL,
  `pass_accuracy` decimal(12,6) NULL,

  -- Attacking Threat
  `dangerous_attacks_per_match` decimal(12,6) NULL,
  `total_crosses_per_match` decimal(12,6) NULL,
  `cross_accuracy` decimal(12,6) NULL,
  `dribble_attempts_per_match` decimal(12,6) NULL,
  `dribble_success_rate` decimal(12,6) NULL,

  -- Chance Creation
  `corners_per_match` decimal(12,6) NULL,
  `key_passes_per_match` decimal(12,6) NULL,
  `big_chances_created_per_match` decimal(12,6) NULL,

  -- Finishing
  `shots_insidebox_per_match` decimal(12,6) NULL,
  `conversion_rate` decimal(12,6) NULL,
  `shots_on_target_per_match` decimal(12,6) NULL,
  `shot_accuracy` decimal(12,6) NULL,

  -- Defending
  -- These are opponent stats allowed by this team.
  -- Lower raw values are better, so trainer should flip z-scores for these features.
  `goals_against_per_match` decimal(12,6) NULL,
  `shots_on_target_against_per_match` decimal(12,6) NULL,
  `shots_insidebox_against_per_match` decimal(12,6) NULL,
  `big_chances_against_per_match` decimal(12,6) NULL,
  `dangerous_attacks_against_per_match` decimal(12,6) NULL,

  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_team_attribute_training_features_scope` (`league_id`, `season_id`, `team_id`),
  KEY `idx_team_attribute_training_features_season` (`season_id`),
  KEY `idx_team_attribute_training_features_league_season` (`league_id`, `season_id`),
  KEY `idx_team_attribute_training_features_team` (`team_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;