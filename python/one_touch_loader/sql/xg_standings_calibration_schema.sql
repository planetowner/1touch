CREATE TABLE IF NOT EXISTS xg_standings_calibration (
  league_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,

  method VARCHAR(64) NOT NULL DEFAULT 'historical_draw_rate',
  lookback_seasons SMALLINT UNSIGNED NOT NULL,
  calibration_match_count INT UNSIGNED NOT NULL,

  target_draw_rate DECIMAL(7,6) NOT NULL,
  draw_band DECIMAL(9,3) NOT NULL,

  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (league_id, season_id, method),

  KEY idx_xg_standings_calibration_season (season_id),

  CONSTRAINT fk_xg_stand_calib_league
    FOREIGN KEY (league_id) REFERENCES leagues(league_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_xg_stand_calib_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Stores draw-band calibration metadata for 1touch xG W/D/L standings.';