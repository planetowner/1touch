-- 계정 이름과 분리해 경기별 익명 닉네임을 보관해요. 탈퇴하면 계정과의 연결도 지워요.
CREATE TABLE fixture_chat_aliases (
    fixture_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    nickname_en VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nickname_ko VARCHAR(80) COLLATE utf8mb4_bin NOT NULL,
    PRIMARY KEY (fixture_id, user_id),
    FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    -- 한 경기에서 이름이 겹치거나 같은 회원이 다른 경기에서 같은 이름을 받지 않아요.
    UNIQUE KEY room_nickname_en (fixture_id, nickname_en),
    UNIQUE KEY room_nickname_ko (fixture_id, nickname_ko),
    UNIQUE KEY user_nickname_en (user_id, nickname_en),
    UNIQUE KEY user_nickname_ko (user_id, nickname_ko)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
