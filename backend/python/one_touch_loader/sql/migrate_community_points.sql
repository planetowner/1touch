-- 가입·베팅 원장과 잔액을 유지한 채 커뮤니티 적립을 같은 지갑에 연결해요.
ALTER TABLE user_point_wallets ADD COLUMN country_code CHAR(2) CHARACTER SET ascii NULL;

ALTER TABLE user_point_entries
    MODIFY kind ENUM('welcome','bet_place','bet_change','bet_cancel','bet_win','bet_loss','bet_refund',
        'community_post','community_like','community_comment','community_quality') NOT NULL,
    ADD COLUMN post_id BIGINT UNSIGNED NULL,
    ADD KEY community_point_day (user_id,created_at,kind),
    ADD KEY community_post_points (post_id,kind),
    ADD CONSTRAINT point_entry_post FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE SET NULL;
