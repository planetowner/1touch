-- 이미 저장한 카카오 표식을 유지하고 Apple도 같은 중복 수신 규칙을 사용해요.
RENAME TABLE kakao_webhook_receipts TO social_webhook_receipts;
ALTER TABLE social_webhook_receipts
    ADD COLUMN provider ENUM('apple','kakao') NOT NULL DEFAULT 'kakao' FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (provider,event_hash);
-- 기존 행을 카카오로 채운 뒤에는 호출하는 코드가 공급자를 명시하도록 기본값을 없애요.
ALTER TABLE social_webhook_receipts ALTER COLUMN provider DROP DEFAULT;
