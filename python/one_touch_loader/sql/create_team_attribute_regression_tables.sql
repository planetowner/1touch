SET NAMES utf8mb4;

DROP TABLE IF EXISTS `team_attribute_regression_weights`;

CREATE TABLE IF NOT EXISTS `team_attribute_regression_models` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,

  `model_name` varchar(100) NOT NULL,
  `model_version` int NOT NULL,
  `target_name` varchar(100) NOT NULL,
  `training_scope` varchar(255) NOT NULL,
  `normalization_scope` varchar(100) NOT NULL,
  `regression_method` varchar(100) NOT NULL,
  `alpha` decimal(12,6) NULL,

  `rows_used` int NOT NULL,
  `r2_score` decimal(12,6) NULL,
  `notes` text NULL,

  `is_active` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_team_attribute_regression_model` (`model_name`, `model_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `team_attribute_regression_weights` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,

  `model_id` bigint unsigned NOT NULL,
  `attribute_group` varchar(100) NOT NULL,
  `feature_name` varchar(100) NOT NULL,

  -- Original signed coefficient from Ridge regression.
  `coefficient` decimal(14,8) NOT NULL,

  -- max(coefficient, 0). Used for UI-friendly attribute weighting.
  `positive_coefficient` decimal(14,8) NOT NULL,

  -- Normalized positive coefficient inside each attribute group.
  -- This is what team_attribute_group_scores uses.
  `weight` decimal(14,8) NOT NULL,

  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_team_attribute_regression_weight`
    (`model_id`, `attribute_group`, `feature_name`),

  KEY `idx_team_attribute_regression_weights_model` (`model_id`),
  KEY `idx_team_attribute_regression_weights_group` (`attribute_group`),

  CONSTRAINT `fk_team_attribute_regression_weights_model`
    FOREIGN KEY (`model_id`)
    REFERENCES `team_attribute_regression_models` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;