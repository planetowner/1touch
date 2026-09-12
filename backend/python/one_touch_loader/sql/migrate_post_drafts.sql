-- 초안도 같은 제목·본문·첨부 관계를 써요. 별도 테이블이나 만료 시각 컬럼을 만들지 않아요.
-- draft의 edited_at은 마지막 저장 시각이고, 게시할 때 created_at을 게시 시각으로 바꿔요.
ALTER TABLE posts MODIFY state ENUM('active','deleted','hidden','draft') NOT NULL DEFAULT 'active';
