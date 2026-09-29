-- 아이디와 같은 대소문자 구분 규칙으로 닉네임 중복을 판단해요.
ALTER TABLE users MODIFY COLUMN display_name VARCHAR(100) COLLATE utf8mb4_0900_as_ci NULL;

-- 공개 닉네임의 중복은 동시 가입·수정에서도 DB가 막아요.
ALTER TABLE users ADD UNIQUE KEY unique_user_display_name (display_name);
