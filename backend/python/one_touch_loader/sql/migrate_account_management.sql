-- 시간대는 개인정보로 저장하지 않고 각 요청의 기기 시간대를 사용해요.
ALTER TABLE users DROP COLUMN timezone;

-- 기존 가입·비밀번호 복구 코드는 보존하고 같은 일회용 코드 표에 필요한 용도만 추가해요.
ALTER TABLE email_verification_codes MODIFY COLUMN purpose
    ENUM('signup','password_reset','username_recovery','email_change') NOT NULL;
