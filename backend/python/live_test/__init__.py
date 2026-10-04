"""분리된 테스트 작업 폴더에서만 쓰는 스페인 2부 설정이에요."""
import os

COMPETITION_ID = 567
SEASON_ID = 28479
SEASON_NAME = '2026/2027'
DATABASE = 'onetouch_live_test'
DOMESTIC_COMPETITION_IDS = (8, 82, 301, 384, 564, COMPETITION_ID)
DOMESTIC_COMPETITION_SQL = ','.join(map(str, DOMESTIC_COMPETITION_IDS))

# 2026-10-04 Sportmonks 참가팀과 ClubElo의 스페인 2부 목록을 대조했어요.
# 리저브팀은 1군과 다른 식별자를 써요. 이름이 비슷하다고 연결하지 않아요.
CLUBELO_TEAMS = {
    'Castellon': 10008, 'Cordoba': 931, 'Burgos': 8366, 'Eldense': 1888,
    'Tenerife': 1012, 'rc-celta-b': 384, 'Granada': 103, 'Gijon': 344,
    'Oviedo': 93, 'LasPalmas': 2921, 'ad-ceuta-fc': 12330, 'SociedadB': 9656,
    'Eibar': 60, 'Valladolid': 361, 'Cadiz': 6827, 'Mallorca': 645,
    'Girona': 231, 'Leganes': 844, 'Sabadell': 758, 'Albacete': 3169,
    'Almeria': 618, 'fc-andorra': 238115,
}


def require_test_database():
    # 운영 DB로 잘못 접속한 채 적재·정산·푸시를 실행하지 않아요.
    if os.environ.get('DB_NAME') != DATABASE:
        raise RuntimeError(f'This test checkout requires DB_NAME={DATABASE}')
    from one_touch_loader.core.db import fetch_all
    if fetch_all('SELECT DATABASE()')[0][0] != DATABASE:
        raise RuntimeError('The connected database is not the live-test database')
