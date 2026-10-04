"""운영 DB에서 구조와 공개 국가·포지션 사전만 읽어요. 회원 데이터는 복사하지 않아요."""
import re
from one_touch_loader.core.db import get_conn


def export():
    with get_conn() as conn, conn.cursor() as cur:
        conn.start_transaction(readonly=True, consistent_snapshot=True)
        cur.execute('SELECT TABLE_NAME,TABLE_TYPE FROM information_schema.TABLES '
                    'WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_TYPE,TABLE_NAME')
        objects = cur.fetchall()
        statements = ['SET FOREIGN_KEY_CHECKS=0']
        for name, kind in objects:
            quoted = '`' + name.replace('`', '``') + '`'
            cur.execute(f'SHOW CREATE {"VIEW" if kind == "VIEW" else "TABLE"} {quoted}')
            ddl = cur.fetchone()[1]
            # 운영 root의 DEFINER를 새 DB에 옮기지 않고 테스트 계정으로 뷰를 만들어요.
            ddl = re.sub(r'DEFINER=`[^`]+`@`[^`]+` ', '', ddl)
            statements.append(ddl)
        print(';\n'.join(statements) + ';')
        for table in ('countries', 'positions'):
            cur.execute(f'SELECT * FROM `{table}`')
            columns = ','.join('`' + field[0] + '`' for field in cur.description)
            for row in cur.fetchall():
                # 문자열을 UTF-8 16진수로 옮겨 SQL 모드에 따른 인용 차이를 없애요.
                values = ['NULL' if value is None else
                          "CONVERT(X'" + str(value).encode().hex() + "' USING utf8mb4)" for value in row]
                print(f'INSERT INTO `{table}` ({columns}) VALUES ({",".join(values)});')
        print('SET FOREIGN_KEY_CHECKS=1;')
        conn.rollback()


if __name__ == '__main__':
    export()
