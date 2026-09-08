CREATE TABLE stage_types (
  stage_type_id INT NOT NULL,
  code          VARCHAR(50) NOT NULL,
  name          VARCHAR(50) NOT NULL,

  PRIMARY KEY (stage_type_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO stage_types (stage_type_id, code, name)
VALUES
  (223, 'group-stage', 'GROUP_STAGE'),
  (224, 'knock-out', 'KNOCK_OUT'),
  (225, 'qualifying', 'QUALIFYING');

ALTER TABLE stages
  DROP INDEX idx_stages_competition_season_type,
  DROP COLUMN competition_id,
  MODIFY COLUMN season_id BIGINT UNSIGNED NOT NULL,
  CHANGE COLUMN type_id stage_type_id INT NOT NULL,
  ADD KEY idx_stages_season_type (season_id, stage_type_id),
  ADD CONSTRAINT fk_stages_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_stages_stage_type
    FOREIGN KEY (stage_type_id) REFERENCES stage_types(stage_type_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

SELECT column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'stages'
ORDER BY ordinal_position;

SELECT stage_type_id, code, name
FROM stage_types
ORDER BY stage_type_id;

SELECT
  constraint_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND table_name = 'stages'
  AND referenced_table_name IS NOT NULL
ORDER BY constraint_name;
