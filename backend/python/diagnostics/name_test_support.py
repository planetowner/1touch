"""감독·선수 이름 저장 테스트가 같은 메모리 DB 연결을 사용해요."""
import sqlite3


class NameMigrationDatabase:
    def __init__(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("CREATE TABLE teams (team_id INTEGER PRIMARY KEY, name TEXT, short_name TEXT, name_ko TEXT)")
        self.db.execute("CREATE TABLE players (player_id INTEGER PRIMARY KEY, display_name TEXT, full_name TEXT, display_name_ko TEXT)")
        self.db.executemany("INSERT INTO teams VALUES (?, ?, ?, ?)", [(8, "Liverpool", "LFC", None), (9, "Other", "OTH", None)])
        self.db.executemany("INSERT INTO players VALUES (?, ?, ?, ?)", [(997, "Harry Kane", "Harry Kane", None), (1, "Other", "Other Full", None)])
        self.db.commit()
        db = self.db

        class Cursor:
            def __enter__(self):
                self.cursor = db.cursor()
                return self

            def __exit__(self, *args):
                self.cursor.close()

            def execute(self, sql, params=()):
                # MySQL 쿼리를 메모리 SQLite에서 실행하도록 문법만 맞춰요.
                return self.cursor.execute(sql.replace("%s", "?").replace(" FOR UPDATE", ""), params)

            @property
            def description(self):
                return self.cursor.description

            def fetchall(self):
                return self.cursor.fetchall()

        class Connection:
            def cursor(self):
                return Cursor()

            def start_transaction(self):
                db.execute("BEGIN")

            def commit(self):
                db.commit()

            def rollback(self):
                db.rollback()

        self.connection = Connection()

    def close(self):
        self.db.close()
