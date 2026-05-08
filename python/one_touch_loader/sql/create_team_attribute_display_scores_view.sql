SET NAMES utf8mb4;

DROP VIEW IF EXISTS `v_team_attribute_display_scores`;

CREATE VIEW `v_team_attribute_display_scores` AS
SELECT
  s.model_id,
  s.league_id,
  s.season_id,
  s.team_id,
  t.name AS team_name,

  ROUND(MAX(CASE WHEN s.attribute_group = 'possession_build_up'
    THEN s.display_score_0_100 END), 2) AS possession_build_up,

  ROUND(MAX(CASE WHEN s.attribute_group = 'attacking_threat'
    THEN s.display_score_0_100 END), 2) AS attacking_threat,

  ROUND(MAX(CASE WHEN s.attribute_group = 'chance_creation'
    THEN s.display_score_0_100 END), 2) AS chance_creation,

  ROUND(MAX(CASE WHEN s.attribute_group = 'finishing'
    THEN s.display_score_0_100 END), 2) AS finishing,

  ROUND(MAX(CASE WHEN s.attribute_group = 'defending'
    THEN s.display_score_0_100 END), 2) AS defending,

  MAX(s.updated_at) AS attributes_updated_at

FROM team_attribute_group_scores s
JOIN team_attribute_regression_models m
  ON m.id = s.model_id
 AND m.is_active = 1

LEFT JOIN teams t
  ON t.team_id = s.team_id

GROUP BY
  s.model_id,
  s.league_id,
  s.season_id,
  s.team_id,
  t.name;