ALTER TABLE team_seasons
  DROP INDEX idx_ts_competition_season,
  DROP COLUMN competition_id,
  RENAME INDEX idx_ts_season TO idx_team_seasons_season,
  ADD CONSTRAINT fk_team_seasons_team
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_team_seasons_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'team_seasons'
ORDER BY ordinal_position;

SELECT
  index_name,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'team_seasons'
GROUP BY index_name
ORDER BY index_name;

SELECT
  constraint_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND table_name = 'team_seasons'
  AND referenced_table_name IS NOT NULL
ORDER BY constraint_name;
