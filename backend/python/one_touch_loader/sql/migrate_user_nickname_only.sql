-- 닉네임이 없는 기존 이메일 회원은 화면에 표시하던 아이디를 이어서 써요.
-- 적용할 계정의 아이디가 닉네임 형식과 중복 검사를 통과했는지 먼저 확인해요.
UPDATE users u
JOIN user_email_credentials e ON e.user_id = u.user_id
SET u.display_name = u.username
WHERE u.display_name IS NULL OR u.display_name = '';

-- 이름을 참조하지 않는 서버·앱 코드와 함께 적용해요.
ALTER TABLE users DROP COLUMN first_name, DROP COLUMN last_name;

-- 이메일 로그인 정보가 없는 소셜 회원은 로그인 아이디를 사용하지 않아요.
UPDATE users u
JOIN user_social_identities s ON s.user_id = u.user_id
LEFT JOIN user_email_credentials e ON e.user_id = u.user_id
SET u.username = NULL
WHERE e.user_id IS NULL;
