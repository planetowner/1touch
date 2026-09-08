ALTER TABLE players
  ADD KEY idx_players_nationality (nationality_id),
  ADD CONSTRAINT fk_players_nationality
    FOREIGN KEY (nationality_id) REFERENCES countries(country_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'countries'
ORDER BY ordinal_position;

SELECT COUNT(*) AS countries_count
FROM countries;

SELECT
  constraint_name,
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND constraint_name = 'fk_players_nationality';
