-- 주장단을 모두 주장으로 적재한 행을 C·VC 직책에 맞춰 바로잡아요.
-- 시즌 중 실제 주장 교체와 동급으로 지정된 복수 부주장은 유지해요.
START TRANSACTION;

-- 바르셀로나: 하피냐 주장, 페드리 부주장.
DELETE FROM team_leadership_assignments
WHERE team_id=83 AND season_id=27965 AND leadership_role='captain'
  AND player_id IN (26536,4545389,37656179);
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=83 AND season_id=27965 AND player_id=37288001 AND leadership_role='captain';

-- 토트넘: 반더벤 주장, 원문에 명시된 포로 부주장.
DELETE FROM team_leadership_assignments
WHERE team_id=6 AND season_id=28083 AND leadership_role='captain'
  AND player_id IN (989,6838,37581741);
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=6 AND season_id=28083 AND player_id=8456257 AND leadership_role='captain';

-- 맨시티: 구단 발표는 네 명의 주장단만 명시해요.
-- 초반 완장을 찬 디아스와 8월 시즌 문서의 홀란 부주장 표기를 따라요.
DELETE FROM team_leadership_assignments
WHERE team_id=9 AND season_id=28083 AND leadership_role='captain'
  AND player_id IN (129771,4536500);
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=9 AND season_id=28083 AND player_id=154421 AND leadership_role='captain';

-- 엘체: 원문에 명시된 비가스 주장, 호산 부주장만 남겨요.
DELETE FROM team_leadership_assignments
WHERE team_id=1099 AND season_id=25659 AND leadership_role='captain'
  AND player_id IN (213939,436041,446998,37259638);
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=1099 AND season_id=25659 AND player_id=189118 AND leadership_role='captain';

-- 비야레알: 원문에 명시된 제라르 주장, 포이스 부주장만 남겨요.
DELETE FROM team_leadership_assignments
WHERE team_id=3477 AND season_id=27965 AND leadership_role='captain'
  AND player_id IN (1396,189585,12394069,26328601);
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=3477 AND season_id=27965 AND player_id=335705 AND leadership_role='captain';

-- 세비야: 나무위키 선수단 표의 수아소 주장·마르캉 부주장 표기를 따라요.
DELETE FROM team_leadership_assignments
WHERE team_id=676 AND season_id=27965 AND player_id=37553227 AND leadership_role='captain';
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=676 AND season_id=27965 AND player_id=219730 AND leadership_role='captain';

-- 마르세유 2019/20: 감독은 만단다를 시즌 주장으로 지명했어요.
DELETE FROM team_leadership_assignments
WHERE team_id=44 AND season_id=16043 AND leadership_role='captain'
  AND player_id IN (1413,4237,30328);

-- 아탈란타 2020/21: 고메스에서 톨로이로 주장이 교체됐어요.
-- 프뢰일러와 더론은 이후 구단이 두 명 모두 부주장으로 명시했어요.
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=708 AND season_id=17488 AND leadership_role='captain'
  AND player_id IN (130145,1717);

-- 렌 2023/24: 부리조에서 만단다로 주장이 교체됐어요.
-- 마티치는 경기장 안의 리더로 지명됐지만 시즌 주장은 아니에요.
DELETE FROM team_leadership_assignments
WHERE team_id=598 AND season_id=21779 AND player_id=1335 AND leadership_role='captain';

-- 스트라스부르 2024/25: 디아라 주장, 안드레이 산투스 부주장.
UPDATE team_leadership_assignments SET leadership_role='vice_captain'
WHERE team_id=686 AND season_id=23643 AND player_id=37562129 AND leadership_role='captain';

COMMIT;

SELECT t.name AS team_name,s.name AS season_name,a.leadership_role,p.display_name AS player_name
FROM team_leadership_assignments a
JOIN teams t ON t.team_id=a.team_id
JOIN seasons s ON s.season_id=a.season_id
JOIN players p ON p.player_id=a.player_id
WHERE (a.team_id,a.season_id) IN
  ((83,27965),(6,28083),(9,28083),(1099,25659),(3477,27965),(676,27965),
   (44,16043),(708,17488),(598,21779),(686,23643))
ORDER BY s.name,t.name,a.leadership_role,a.player_id;

SELECT COUNT(*) AS total_assignments FROM team_leadership_assignments;
