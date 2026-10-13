-- FC 바르셀로나 공식 선수 소개의 표기로 일반 이름과 짧은 이름을 맞춰요.
-- https://www.fcbarcelona.jp/ja/football/primer-equipo/jugadores/24156/raphinha
SET NAMES utf8mb4;

START TRANSACTION;
UPDATE players
SET display_name_ja = 'ハフィーニャ', short_name_ja = 'ハフィーニャ'
WHERE player_id = 160258
  AND display_name = 'Raphinha'
  AND date_of_birth = '1996-12-14';
COMMIT;

SELECT player_id, display_name, display_name_ja, short_name_ja
FROM players
WHERE player_id = 160258;
