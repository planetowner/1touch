-- 기존 안내가 0건임을 사전 검사한 뒤 고정 번호를 언어로 바꿔요.
-- 같은 언어의 안내는 모든 팀이 공유하며, 제목과 번호 목록은 본문에 함께 보관해요.
ALTER TABLE community_rules
    DROP CHECK community_rules_chk_1,
    DROP PRIMARY KEY,
    DROP COLUMN rules_id,
    ADD COLUMN language ENUM('ko','en') CHARACTER SET ascii COLLATE ascii_bin NOT NULL FIRST,
    ADD PRIMARY KEY (language);
