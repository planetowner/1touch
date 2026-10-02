"""원장 동작을 검사하는 메모리 DB 테스트가 같은 테이블 정의를 사용해요."""


def create_point_tables(connection):
    connection.executescript('''
        CREATE TABLE user_point_wallets (
            user_id INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
            balance INTEGER NOT NULL CHECK(balance>=0), country_code TEXT,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
        CREATE TABLE user_point_entries (
            entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            bet_id INTEGER, post_id INTEGER REFERENCES posts(post_id) ON DELETE SET NULL,
            request_id TEXT NOT NULL CHECK(length(request_id)<=64), request_hash TEXT NOT NULL,
            kind TEXT NOT NULL, amount INTEGER NOT NULL, balance_after INTEGER NOT NULL CHECK(balance_after>=0),
            bet_revision INTEGER, created_at TEXT NOT NULL, UNIQUE(user_id,request_id));
    ''')
