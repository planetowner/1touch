"""공식 발표로 확인했지만 공급자 이적 응답에는 없는 이동이에요."""

# 8_000_000_000_000_001·002는 1Touch 보정 ID이며 Sportmonks ID가 아니에요.
# 기존 UNSIGNED BIGINT와 웹의 정확한 정수 범위 안에서 공급자 ID와 구분해요.
# 같은 날 매입 뒤 재임대가 정렬되도록 공급자 매입 ID보다 큰 값을 사용해요.
# 2026-10-16 운영 이적 ID 범위는 1~605298이었어요.
# 선수·KSC·Freiburg 정보는 같은 날 받은 Sportmonks 이적 응답에서 가져왔어요.
# Koblenz 5071은 아래 공급자 배지의 구단명과 공식 입단 발표를 대조했어요.
# https://cdn.sportmonks.com/images/soccer/teams/15/5071.png
# https://gioscore.com/football/team/fc-rot-weiss-koblenz/5071
#
# Ben Farhat: 9/1 완전 이적 직후 KSC 재임대를 양 구단이 발표했어요.
# https://www.ksc.de/ksc-drei60/startseite-ksc-drei60/ksc-drei60-sehen/show/article/louey-ben-farhat-wechsel-zum-sc-freiburg-rueckleihe-zum-ksc/
# https://www.scfreiburg.com/en/latest/first-team/news/2026-27/ben-farhat-joins-sc-and-returns-to-ksc-on-loan
# Pantschenko: 9/2 공지는 마감일 입단을 명시하고, DFL은 마감일을 9/1로 확인해요.
# 7/1 퇴단은 보존하고 새 입단을 별도로 추가해 중간 소속을 추정하지 않아요.
# https://www.fcrotweisskoblenz.de/pantschenko-rwk-ist-der-richtig-verein-fuer-mich/
# https://www.fcrotweisskoblenz.de/aktuelles/
# https://www.bundesliga.com/en/bundesliga/news/official-bundesliga-transfer-centre-summer-2026-37051
# 임대료·이적료·계약 종료일은 확인하지 못했으므로 채우지 않아요.
VERIFIED_TRANSFER_ADDITIONS = {
    8000000000000001: {
        'player_id': 37652834,
        'from_team_id': 3543,
        'to_team_id': 3114,
        'type_id': 218,
        'date': '2026-09-01',
        'completed': True,
        'amount': None,
        'fromteam': {
            'id': 3543,
            'name': 'SC Freiburg',
            'short_code': 'SCF',
            'image_path': 'https://cdn.sportmonks.com/images/soccer/teams/23/3543.png',
            'placeholder': False,
        },
        'toteam': {
            'id': 3114,
            'name': 'Karlsruher SC',
            'short_code': 'KSC',
            'image_path': 'https://cdn.sportmonks.com/images/soccer/teams/10/3114.png',
            'placeholder': False,
        },
        'type': {
            'id': 218,
            'name': 'Loan',
        },
        'player': {
            'id': 37652834,
            'sport_id': 1,
            'country_id': 11,
            'nationality_id': 1439,
            'city_id': None,
            'position_id': 26,
            'detailed_position_id': None,
            'type_id': None,
            'common_name': 'L. Farhat',
            'firstname': 'Louey Ben',
            'lastname': 'Farhat',
            'name': 'Louey Ben Farhat',
            'display_name': 'Louey Ben Farhat',
            'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png',
            'height': 175,
            'weight': 61,
            'date_of_birth': '2006-07-19',
            'gender': 'male',
        },
        'id': 8000000000000001,
    },
    8000000000000002: {
        'player_id': 37707501,
        'from_team_id': None,
        'to_team_id': 5071,
        'type_id': 219,
        'date': '2026-09-01',
        'completed': True,
        'amount': None,
        'fromteam': None,
        'toteam': {
            'id': 5071,
            'name': 'FC Rot-Weiss Koblenz',
            'short_code': None,
            'image_path': 'https://cdn.sportmonks.com/images/soccer/teams/15/5071.png',
            'placeholder': False,
        },
        'type': {
            'id': 219,
            'name': 'Transfer',
        },
        'player': {
            'id': 37707501,
            'sport_id': 1,
            'country_id': 11,
            'nationality_id': 11,
            'city_id': None,
            'position_id': 26,
            'detailed_position_id': 149,
            'type_id': None,
            'common_name': 'D. Pantschenko',
            'firstname': 'Daniel',
            'lastname': 'Pantschenko',
            'name': 'Daniel Pantschenko',
            'display_name': 'Daniel Pantschenko',
            'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png',
            'height': 177,
            'weight': 71,
            'date_of_birth': '2003-01-16',
            'gender': 'male',
        },
        'id': 8000000000000002,
    },
}
