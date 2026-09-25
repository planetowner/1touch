-- 기존 분류의 ENUM 순서는 유지하고 팬아트를 마지막에 추가해요.
ALTER TABLE posts
    MODIFY COLUMN category ENUM('general','analysis','news','fanart') NOT NULL;
