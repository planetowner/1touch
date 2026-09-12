SELECT
    (SELECT COUNT(*) FROM players WHERE player_id = 73643) AS duplicate_players_before,
    (SELECT COUNT(*) FROM player_external_ids WHERE player_id = 73643) AS duplicate_external_ids_before,
    (SELECT COUNT(*) FROM team_squad_members WHERE player_id = 73643) AS duplicate_squad_members_before,
    (SELECT COUNT(*) FROM players WHERE player_id = 74062) AS canonical_players_before;

START TRANSACTION;

DELETE FROM team_squad_members
WHERE player_id = 73643;

SELECT ROW_COUNT() AS deleted_duplicate_squad_members;

DELETE FROM player_external_ids
WHERE player_id = 73643;

SELECT ROW_COUNT() AS deleted_duplicate_external_ids;

-- 73643은 Toma Bašić(74062)와 중복되고 Josip Bašić의 프로필 정보가 섞인
-- Sportmonks 행이에요. 정상 선수와 Capology 매핑은 74062에 그대로 남겨요.
DELETE FROM players
WHERE player_id = 73643;

SELECT ROW_COUNT() AS deleted_duplicate_players;

COMMIT;

SELECT
    (SELECT COUNT(*) FROM players WHERE player_id = 73643) AS duplicate_players_after,
    (SELECT COUNT(*) FROM player_external_ids WHERE player_id = 73643) AS duplicate_external_ids_after,
    (SELECT COUNT(*) FROM team_squad_members WHERE player_id = 73643) AS duplicate_squad_members_after,
    (SELECT COUNT(*) FROM players WHERE player_id = 74062) AS canonical_players_after;

SELECT player_id, display_name, full_name, date_of_birth, position_id
FROM players
WHERE player_id = 74062;

SELECT player_id, provider, external_player_id
FROM player_external_ids
WHERE player_id = 74062
ORDER BY provider;
