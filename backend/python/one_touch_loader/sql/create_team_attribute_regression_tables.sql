SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `team_attribute_regression_models` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,

  `model_name` varchar(100) NOT NULL,
  `model_version` int NOT NULL,
  `target_name` varchar(100) NOT NULL,
  `training_scope` varchar(255) NOT NULL,
  `normalization_scope` varchar(100) NOT NULL,
  `regression_method` varchar(100) NOT NULL,
  `alpha` decimal(12,6) NULL,

-- 전체 입력 행 수와 영역별 학습 R²의 평균이에요. 영역별 실제 학습 행 수·절편·R²는 notes에 남겨요.
  `rows_used` int NOT NULL,
  `r2_score` decimal(12,6) NULL,
  `notes` text NULL,

  `is_active` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_team_attribute_regression_model` (`model_name`, `model_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE IF NOT EXISTS `team_attribute_regression_weights` (

  `model_id` bigint unsigned NOT NULL,
  `attribute_group` varchar(100) NOT NULL,
  `feature_name` varchar(100) NOT NULL,

-- Ridge 회귀가 만든 부호 있는 원본 계수예요.
  `coefficient` decimal(14,8) NOT NULL,

-- 각 특성 그룹 안에서 정규화한 양수 계수예요.
-- team_attribute_group_scores가 이 값을 써요.
  `weight` decimal(14,8) NOT NULL,

  PRIMARY KEY
    (`model_id`, `attribute_group`, `feature_name`),

  CONSTRAINT `fk_team_attribute_regression_weights_model`
    FOREIGN KEY (`model_id`)
    REFERENCES `team_attribute_regression_models` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
