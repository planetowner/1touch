CREATE TABLE IF NOT EXISTS transfer_windows (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  season_year   INT NOT NULL,              -- e.g. 2026
  window_name   VARCHAR(20) NOT NULL,      -- 'winter' | 'summer'
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 0,
  is_latest     TINYINT(1) NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tw_year_window (season_year, window_name),
  KEY idx_tw_latest (is_latest),
  KEY idx_tw_active (is_active),
  KEY idx_tw_dates (start_date, end_date)
);

-- seed: known transfer windows
INSERT IGNORE INTO transfer_windows (season_year, window_name, start_date, end_date) VALUES
  (2025, 'summer', '2025-06-10', '2025-09-01'),
  (2025, 'winter', '2025-12-01', '2025-12-31'),
  (2026, 'winter', '2026-01-01', '2026-02-03'),
  (2026, 'summer', '2026-06-10', '2026-09-01');
