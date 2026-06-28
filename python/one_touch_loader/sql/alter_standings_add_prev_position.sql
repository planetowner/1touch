-- standings.prev_position: the team's official position as of the PREVIOUS
-- round, so rank delta = prev_position - position can be read directly without
-- recomputing standings (and without self-ranking fixtures). Sourced from the
-- Sportmonks standings/rounds endpoint. NULL when there is no previous round
-- (matchday 1) or where rank delta does not apply (euro group/league-phase).
--
-- MySQL has no "ADD COLUMN IF NOT EXISTS" in older versions; run once.
ALTER TABLE standings ADD COLUMN prev_position INT NULL AFTER position;
