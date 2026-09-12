-- 공급자만 추가하고 기존 ID·인덱스·탈퇴 시 연결 삭제 규칙은 유지해요.
-- ENUM 뒤에 추가해야 기존 공급자의 저장 순번이 바뀌지 않아요.
ALTER TABLE user_social_identities
    MODIFY provider ENUM('google','apple','kakao','line') NOT NULL;
