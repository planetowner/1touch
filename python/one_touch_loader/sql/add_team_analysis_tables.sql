-- sql/20260409_add_team_analysis_tables.sql
-- match-by-match team analysis pipeline tables
-- MySQL 8.0+

SET NAMES utf8mb4;

-- =========================================================
-- 1) 경기별 팀 통계 raw 저장
-- =========================================================
CREATE TABLE IF NOT EXISTS `fixture_team_stats_raw` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `fixture_id` bigint unsigned NOT NULL,
  `season_id` bigint unsigned NOT NULL,
  `league_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,
  `opponent_team_id` bigint unsigned NOT NULL,
  `location` enum('home','away') NOT NULL,
  `stat_type_id` int NOT NULL,
  `stat_code` varchar(100) NOT NULL,
  `stat_name` varchar(255) DEFAULT NULL,
  `stat_value_num` decimal(12,4) DEFAULT NULL,
  `raw_data_json` json NOT NULL,
  `collected_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ftsr_fixture_team_code` (`fixture_id`,`team_id`,`stat_code`),
  KEY `idx_ftsr_team` (`team_id`),
  KEY `idx_ftsr_fixture` (`fixture_id`),
  KEY `idx_ftsr_season_league` (`season_id`,`league_id`),
  KEY `idx_ftsr_stat_code` (`stat_code`),
  CONSTRAINT `fk_ftsr_fixture` FOREIGN KEY (`fixture_id`) REFERENCES `fixtures` (`fixture_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ftsr_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`team_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ftsr_opponent_team` FOREIGN KEY (`opponent_team_id`) REFERENCES `teams` (`team_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ftsr_season` FOREIGN KEY (`season_id`) REFERENCES `seasons` (`season_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ftsr_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`league_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =========================================================
-- 2) 경기별 팀 feature 펼친 테이블
-- =========================================================
CREATE TABLE IF NOT EXISTS `fixture_team_features` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `fixture_id` bigint unsigned NOT NULL,
  `season_id` bigint unsigned NOT NULL,
  `league_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,
  `opponent_team_id` bigint unsigned NOT NULL,
  `location` enum('home','away') NOT NULL,

  `accurate_crosses` decimal(12,4) DEFAULT NULL,
  `assists` decimal(12,4) DEFAULT NULL,
  `attacks` decimal(12,4) DEFAULT NULL,
  `ball_possession` decimal(12,4) DEFAULT NULL,
  `ball_safe` decimal(12,4) DEFAULT NULL,
  `big_chances_created` decimal(12,4) DEFAULT NULL,
  `corners` decimal(12,4) DEFAULT NULL,
  `dangerous_attacks` decimal(12,4) DEFAULT NULL,
  `dribble_attempts` decimal(12,4) DEFAULT NULL,
  `duels_won` decimal(12,4) DEFAULT NULL,
  `fouls` decimal(12,4) DEFAULT NULL,
  `free_kicks` decimal(12,4) DEFAULT NULL,
  `goal_attempts` decimal(12,4) DEFAULT NULL,
  `goals` decimal(12,4) DEFAULT NULL,
  `goals_kicks` decimal(12,4) DEFAULT NULL,
  `hit_woodwork` decimal(12,4) DEFAULT NULL,
  `injuries` decimal(12,4) DEFAULT NULL,
  `interceptions` decimal(12,4) DEFAULT NULL,
  `key_passes` decimal(12,4) DEFAULT NULL,
  `long_passes` decimal(12,4) DEFAULT NULL,
  `offsides` decimal(12,4) DEFAULT NULL,
  `passes` decimal(12,4) DEFAULT NULL,
  `saves` decimal(12,4) DEFAULT NULL,
  `shots_blocked` decimal(12,4) DEFAULT NULL,
  `shots_insidebox` decimal(12,4) DEFAULT NULL,
  `shots_off_target` decimal(12,4) DEFAULT NULL,
  `shots_on_target` decimal(12,4) DEFAULT NULL,
  `shots_outsidebox` decimal(12,4) DEFAULT NULL,
  `shots_total` decimal(12,4) DEFAULT NULL,
  `substitutions` decimal(12,4) DEFAULT NULL,
  `successful_dribbles` decimal(12,4) DEFAULT NULL,
  `successful_dribbles_percentage` decimal(12,4) DEFAULT NULL,
  `successful_headers` decimal(12,4) DEFAULT NULL,
  `successful_long_passes` decimal(12,4) DEFAULT NULL,
  `successful_long_passes_percentage` decimal(12,4) DEFAULT NULL,
  `successful_passes` decimal(12,4) DEFAULT NULL,
  `successful_passes_percentage` decimal(12,4) DEFAULT NULL,
  `tackles` decimal(12,4) DEFAULT NULL,
  `throwins` decimal(12,4) DEFAULT NULL,
  `total_crosses` decimal(12,4) DEFAULT NULL,
  `yellowcards` decimal(12,4) DEFAULT NULL,

  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ftf_fixture_team` (`fixture_id`,`team_id`),
  KEY `idx_ftf_team` (`team_id`),
  KEY `idx_ftf_fixture` (`fixture_id`),
  KEY `idx_ftf_season_league` (`season_id`,`league_id`),

  CONSTRAINT `fk_ftf_fixture` FOREIGN KEY (`fixture_id`) REFERENCES `fixtures` (`fixture_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ftf_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`team_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ftf_opponent_team` FOREIGN KEY (`opponent_team_id`) REFERENCES `teams` (`team_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ftf_season` FOREIGN KEY (`season_id`) REFERENCES `seasons` (`season_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_ftf_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`league_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =========================================================
-- 3) 점수 공식 버전
-- =========================================================
CREATE TABLE IF NOT EXISTS `score_models` (
  `model_id` bigint NOT NULL AUTO_INCREMENT,
  `model_name` varchar(100) NOT NULL,
  `scope_type` enum('fixture') NOT NULL DEFAULT 'fixture',
  `version` int NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `normalization_method` enum('minmax') NOT NULL DEFAULT 'minmax',
  `is_active` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`model_id`),
  UNIQUE KEY `uq_score_models_name_version_scope` (`model_name`,`version`,`scope_type`),
  KEY `idx_score_models_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =========================================================
-- 4) 점수 공식의 feature 가중치
-- =========================================================
CREATE TABLE IF NOT EXISTS `score_model_weights` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `model_id` bigint NOT NULL,
  `attribute_name` enum('Attack','Progression','Pressure','Dominance','Defense','Possession') NOT NULL,
  `feature_name` varchar(100) NOT NULL,
  `weight` decimal(12,6) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_score_model_weights` (`model_id`,`attribute_name`,`feature_name`),
  KEY `idx_score_model_weights_model` (`model_id`),
  CONSTRAINT `fk_score_model_weights_model` FOREIGN KEY (`model_id`) REFERENCES `score_models` (`model_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =========================================================
-- 5) 최종 팀 attribute 점수
-- =========================================================
CREATE TABLE IF NOT EXISTS `team_attribute_scores` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `model_id` bigint NOT NULL,
  `fixture_id` bigint unsigned NOT NULL,
  `season_id` bigint unsigned NOT NULL,
  `league_id` bigint unsigned NOT NULL,
  `team_id` bigint unsigned NOT NULL,
  `opponent_team_id` bigint unsigned NOT NULL,
  `location` enum('home','away') NOT NULL,

  `attack_score` decimal(12,4) DEFAULT NULL,
  `progression_score` decimal(12,4) DEFAULT NULL,
  `pressure_score` decimal(12,4) DEFAULT NULL,
  `dominance_score` decimal(12,4) DEFAULT NULL,
  `defense_score` decimal(12,4) DEFAULT NULL,
  `possession_score` decimal(12,4) DEFAULT NULL,

  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tas_model_fixture_team` (`model_id`,`fixture_id`,`team_id`),
  KEY `idx_tas_fixture` (`fixture_id`),
  KEY `idx_tas_team` (`team_id`),
  KEY `idx_tas_season_league` (`season_id`,`league_id`),

  CONSTRAINT `fk_tas_model` FOREIGN KEY (`model_id`) REFERENCES `score_models` (`model_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tas_fixture` FOREIGN KEY (`fixture_id`) REFERENCES `fixtures` (`fixture_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tas_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`team_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tas_opponent_team` FOREIGN KEY (`opponent_team_id`) REFERENCES `teams` (`team_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tas_season` FOREIGN KEY (`season_id`) REFERENCES `seasons` (`season_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tas_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`league_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =========================================================
-- 6) 초기 score model 1개 생성
-- =========================================================
INSERT INTO `score_models` (
  `model_name`,
  `scope_type`,
  `version`,
  `description`,
  `normalization_method`,
  `is_active`
)
VALUES (
  'match_attribute_v1',
  'fixture',
  1,
  'Initial hand-crafted match attribute model for Attack/Progression/Pressure/Dominance/Defense/Possession',
  'minmax',
  1
)
ON DUPLICATE KEY UPDATE
  `description` = VALUES(`description`),
  `normalization_method` = VALUES(`normalization_method`);

-- =========================================================
-- 7) 초기 weights 삽입
--    주의: 여기서는 같은 카테고리 내 상대 가중치만 저장.
--    실제 0~100 점수는 코드에서 min-max normalization 후 계산.
-- =========================================================
INSERT INTO `score_model_weights` (`model_id`, `attribute_name`, `feature_name`, `weight`)
SELECT sm.model_id, x.attribute_name, x.feature_name, x.weight
FROM `score_models` sm
JOIN (
  SELECT 'Attack' AS attribute_name, 'goals' AS feature_name, 0.30 AS weight
  UNION ALL SELECT 'Attack', 'shots_on_target', 0.25
  UNION ALL SELECT 'Attack', 'big_chances_created', 0.20
  UNION ALL SELECT 'Attack', 'shots_total', 0.15
  UNION ALL SELECT 'Attack', 'dangerous_attacks', 0.10

  UNION ALL SELECT 'Progression', 'key_passes', 0.25
  UNION ALL SELECT 'Progression', 'successful_passes_percentage', 0.20
  UNION ALL SELECT 'Progression', 'successful_long_passes', 0.20
  UNION ALL SELECT 'Progression', 'accurate_crosses', 0.15
  UNION ALL SELECT 'Progression', 'passes', 0.20

  UNION ALL SELECT 'Pressure', 'tackles', 0.30
  UNION ALL SELECT 'Pressure', 'interceptions', 0.30
  UNION ALL SELECT 'Pressure', 'duels_won', 0.25
  UNION ALL SELECT 'Pressure', 'fouls', 0.15

  UNION ALL SELECT 'Dominance', 'ball_possession', 0.30
  UNION ALL SELECT 'Dominance', 'ball_safe', 0.20
  UNION ALL SELECT 'Dominance', 'attacks', 0.20
  UNION ALL SELECT 'Dominance', 'passes', 0.15
  UNION ALL SELECT 'Dominance', 'goals', 0.15

  UNION ALL SELECT 'Defense', 'tackles', 0.25
  UNION ALL SELECT 'Defense', 'interceptions', 0.25
  UNION ALL SELECT 'Defense', 'shots_blocked', 0.20
  UNION ALL SELECT 'Defense', 'saves', 0.15
  UNION ALL SELECT 'Defense', 'duels_won', 0.15

  UNION ALL SELECT 'Possession', 'ball_possession', 0.40
  UNION ALL SELECT 'Possession', 'passes', 0.20
  UNION ALL SELECT 'Possession', 'successful_passes', 0.20
  UNION ALL SELECT 'Possession', 'successful_passes_percentage', 0.20
) x
WHERE sm.model_name = 'match_attribute_v1'
  AND sm.scope_type = 'fixture'
  AND sm.version = 1
ON DUPLICATE KEY UPDATE
  `weight` = VALUES(`weight`);