CREATE TABLE countries (
  country_id BIGINT UNSIGNED NOT NULL,
  name       VARCHAR(120) NOT NULL,
  image_path VARCHAR(512) NULL,

  PRIMARY KEY (country_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
