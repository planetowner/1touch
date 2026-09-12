"""Big 5 참가 이력 밖의 팀은 확인한 Sportmonks ID로만 분류해요."""

from .db import fetch_all

# 이름의 U/B/II 접미사로 판정하지 않고 공식 기록과 대조한 ID를 사용해요.
VERIFIED_SENIOR_TEAM_IDS = {
    # https://www.az.nl/inside-az/nieuws/2023/juli/kerkez-verruilt-az-voor-afc-bournemouth
    61,
    # https://www.olympiacos.org/en/2024/07/09/costinha-joins-olympiacos/
    602,
    # https://www.fc-union-berlin.de/de/meldungen/union-verlaengert-mit-julien-friedrich-5sQ8uy
    4951,
    # https://uslecce.it/pierotti-in-giallorosso/
    3930,
    # https://www.tottenhamhotspur.com/the-club/history/legends/harry-kane
    294, 64,
    # https://www.spl.com.sa/en/news/al-nassr-sign-joao-felix
    605, 2506,
    # https://www.lafc.com/news/lafc-signs-global-football-icon-son-heung-min
    147671,
    # https://www.orlandocitysc.com/news/global-soccer-icon-and-world-cup-winner-antoine-griezmann-to-join-orlando-city-sc
    204,
}
VERIFIED_NON_SENIOR_TEAM_IDS = {
    # https://www.juventus.com/en/news/articles/huijsen-and-yildiz-added-to-the-juventus-first-team
    228725,
    # https://www.rsca.be/nl/decat2027
    261625,
    # https://www.liverpoolfc.com/news/u21s-match-report-liverpool-suffer-pl2-home-defeat-against-west-brom
    236667,
    # Hamburger SV II·U17: https://www.hsv.de/teams/nachwuchs/alle-teams
    3504, 264161,
    # https://www.tottenhamhotspur.com/teams/under-18/players/
    142875,
    # https://www.slbenfica.pt/pt-pt/futebol-formacao/equipa-b/plantel
    2946,
    # Atlético B: https://en.atleticodemadrid.com/noticias/pulido-em-im-very-happy-to-belong-to-this-club-and-have-signed-an-extension-em
    13332,
}


def load_senior_team_ids() -> set[int]:
    # 컵의 외부 상대팀까지 일괄 인정하지 않아요. 수집 점검과 API가 같은 분류를 사용해요.
    rows = fetch_all("""
        SELECT DISTINCT ts.team_id FROM team_seasons ts JOIN seasons s ON s.season_id=ts.season_id
        WHERE s.competition_id IN (8,82,301,384,564)
    """)
    return {row[0] for row in rows} | VERIFIED_SENIOR_TEAM_IDS
