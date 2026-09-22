"""같은 시즌·날짜·양 팀 출전 명단으로 Opta ID를 연결해요."""

from __future__ import annotations

from datetime import datetime
import re

from .identity import normalize_identity_text, validate_external_id_uniqueness


# 구단 프로필과 같은 경기·팀·등번호로 확인한 활동명이에요. DB 이름은 바꾸지 않아요.
PLAYER_NAME_ALIASES = {
    # 19662566의 같은 팀·2번 선수예요. 구단이 쓰는 Dani와 전체 이름 Daniel을 대조했어요.
    # https://www.realmadrid.com/es-ES/el-club/historia/leyendas-futbol/daniel-carvajal-ramos
    31647: ("Dani Carvajal",),
    # https://comofootball.com/player/tasos-douvikas/
    3188026: ("Tasos Douvikas",),
    # https://www.rcdespanyol.com/en/teams/rcd-espanyol/cala/4106
    37544761: ("Cala",),
    # https://www.slbenfica.pt/pt-pt/futebol/plantel-principal/rafa
    159402: ("Rafa",),
    # https://pafosfc.com.cy/pepe-joins-pafos-fc/
    162706: ("Pêpê Rodrigues",),
    # https://www.staderennais.com/equipe-pro/mousa-al-tamari
    474354: ("Mousa Al-Tamari",),
    # https://genoacfc.it/2026/01/29/alexsandro-amorim-de-freitas-e-un-nuovo-giocatore-del-genoa/
    37680350: ("Alex Amorim",),
    # https://www.aekfc.gr/pld/zini-129130.htm?lang=en&path=0
    37342823: ("Zine",),
    # 협회는 Đani, UEFA·Sportmonks는 Džani로 표기해요. 전역 철자 치환은 하지 않아요.
    # https://www.nfsbih.ba/images/2026-D/Dokumenti_2026/Sl.gl._1101_od_05.06.pdf
    24082038: ("Đani Salčin",),
    # https://www.laliga.com/en-US/match/temporada-2025-2026-europa-conference-league-fiorentina-polissya-2
    205906: ("Oleksandr Andriievskyi",),
    # https://upl.ua/en/people/view/65182
    37556063: ("Mykola Haiduchyk",),
    # https://theanalyst.com/players/8353/pedra-munoz
    527371: ("Pedra Muñoz",),
    # https://www.uefa.com/nationalassociations/teams/62180--fc-santa-coloma/squad/
    3510290: ("Abreu",),
    # 구단은 Qurbanlı, UEFA·Sportmonks는 Gurbanli·Qurbanly로 표기해요. 생일은 2002-04-13이에요.
    # https://qarabagh.com/az/player/view/musa-qurbanli
    9939098: ("Musa Qurbanlı",),
    # 아래 표기는 공개 프로필의 생일과 같은 경기·팀·등번호를 대조했어요.
    # https://www.laliga.com/en-GB/player/aiyegun-tosin
    430249: ("Oluwatosin Aiyegun",),
    # https://theanalyst.com/players/3457/everton-pereira
    37721978: ("Everton Pereira da Silva",),
    # https://www.realmadrid.com/es-ES/futbol/cantera-masculina/castilla/victor-valdepenas-talavera
    37765134: ("Valde",),
    # https://www.sporting.pt/pt/futebol/equipa-principal/plantel/pedro-antonio-pereira-goncalves
    3169778: ("Pote",),
    # https://www.rcdeportivo.es/es/jugadores/depor/alti
    33213465: ("Adrià Alti",),
    # https://theanalyst.com/players/8382/dani-martinez
    37656197: ("Dani Martínez",),
    # https://www.laliga.com/jugador/joselu-7
    37591342: ("Joselu Pérez",),
    # https://theanalyst.com/players/9927/jonas-malede
    12830693: ("Jonas Malede",),
    # 우크라이나 이름의 h/g·i/y는 선수별 표기예요. 다른 사람에게 전역 치환하지 않아요.
    # https://shakhtar.com/en/club/annual-report/-/media/dec797fc6e2747399c8380c2c7155930.ashx
    205892: ("Mykola Matviienko",),
    # https://fcdynamo.com/en/players/oleksandr-pixalyonok
    537243: ("Oleksandr Pikhalionok",),
    # https://fcdynamo.com/en/players/buialskyi-vitaliy
    205413: ("Vitaliy Buialskyi",),
    # https://www.bdfutbol.com/es/j/j29121.html
    160243: ("Benny",),
    # https://www.fotball.no/fotballdata/person/profil/?fiksId=4040960
    37575276: ("Franklin Degaulle Tebo Uchenna",),
    # https://www.soccerbase.com/players/player.sd?player_id=106438
    2510233: ("Christos Shielis",),
    # https://theanalyst.com/players/7681/witi
    160099: ("Witi",),
    # https://theanalyst.com/players/8357/alex-gomez
    37718055: ("Álex Gómez",),
    # https://fcdynamo.com/en/news/georgiy_buschan_meni_sche_e_nad_chim_pratsyuvati
    205349: ("Heorhiy Bushchan",),
    # https://www.uefa.com/european-qualifiers/teams/players/250175409--eduard-sarapii/
    20335145: ("Eduard Sarapii",),
    # https://editorial.uefa.com/resources/029f-1f258283f391-73f2a85d76c9-1000/bookinglist_-_eq_before_md9.pdf
    206146: ("Bohdan Mykhailichenko",),
    # https://fcdynamo.com/en/news/bragaru-ta-pixalyonok-pospilkuvalisya-z-ubolivalnikami-pid-cas-avtografsesiyi-na-stadioni-dinamo
    37261128: ("Maksym Braharu",),
    # 단건 응답의 전체 이름도 같아요. 짧은 DB 표시 이름은 수정하지 않아요.
    # https://theanalyst.com/players/6854/alexander-lind
    24818234: ("Alexander Lucas Lind Rasmussen",),
    # https://www.laliga.com/en-GB/match/temporada-2024-2025-copa-del-rey-pontevedra-cf-villarreal-cf-3
    29313803: ("Dali",),
    # https://theanalyst.com/players/17066/adam-huram
    38212387: ("Adam Abdelilah Huram",),
}


# 이 경기의 Vlahović는 Sportmonks에 24번, Opta에 28번으로 와요.
# 구단·UEFA의 28번과 단건 프로필의 생일(2000-01-28)을 대조했어요. DB 등번호는 유지해요.
# https://www.uefa.com/european-qualifiers/teams/players/250099180--dusan-vlahovic/
SHIRT_NUMBER_ALIASES = {
    (19788662, 177988): 28,
    # UEFA 번호·단건 생일·해당 경기 출전 명단을 대조한 세 슬롯만 보정해요.
    # https://es.uefa.com/uefaeuropaleague/clubs/players/250122232--umut-nayir/
    (19788666, 201712): 14,
    # https://www.uefa.com/newsfiles/UCL/2024/2039006_LU.pdf
    (19788654, 191491): 5,
    # https://www.uefa.com/uefaeuropaleague/clubs/80409--thun/squad/
    (19788654, 37342610): 18,
}


# Pafos–Salzburg의 Anderson은 76분 교체 이벤트만 있고 라인업 행이 없어요.
# UEFA·단건 프로필의 33번·생일(1997-11-21)을 대조했어요. 출전 시간·라인업 행은 만들지 않아요.
# https://it.uefa.com/uefaeuropaleague/clubs/players/250174104--anderson/
VERIFIED_SUBSTITUTION_ROSTER = {
    157460319: (19766394, 8119, 226852, 33),
    # Analysis 원본의 번호·이름과 DB 교체의 선수 ID·단건 프로필을 대조했어요.
    # 앞의 세 선수는 다른 경기에서 확정된 Opta ID도 일치해요.
    157281656: (19719396, 5317, 9302281, 44),
    157355305: (19720994, 554, 67948, 5),
    157459873: (19766394, 49, 37744553, 20),
    # UEFA 명단의 번호·생일도 일치해요. 61분 Braschi·46분 Roth 교체만 보충해요.
    # https://www.uefa.com/news-media/mediaservices/informationkits/competitions/uefaeuropaleague/2027/match/2049124/printmatchpresskits/
    157653472: (19788654, 10655, 37714989, 20),
    157653239: (19788654, 10655, 12830709, 16),
}


def supplement_roster(lineups: list[dict], events: list[dict]) -> list[dict]:
    rows = list(lineups)
    present = {(row["fixture_id"], row["player_id"]) for row in rows}
    for event in events:
        verified = VERIFIED_SUBSTITUTION_ROSTER.get(event["event_id"])
        if (verified is None or event["event_type_id"] != 18
                or (event["fixture_id"], event["team_id"], event["player_id"]) != verified[:3]):
            continue
        key = (event["fixture_id"], event["player_id"])
        if key not in present:
            rows.append({k: event[k] for k in ("fixture_id", "team_id", "player_id", "display_name", "full_name")}
                        | {"jersey_number": verified[3]})
            present.add(key)
    return rows


def player_name_matches(source: str, row: dict) -> bool:
    source_words = normalize_identity_text(source).split()
    source_initials = {normalize_identity_text(x) for x in re.findall(r"\b([^\W\d_])\.", source)}
    for value in (row["display_name"], row["full_name"], *PLAYER_NAME_ALIASES.get(row["player_id"], ())):
        if not value:
            continue
        words = normalize_identity_text(value).split()
        if words == source_words:
            return True
        # Sávio·Yuri·Andrade처럼 이름 중 한 단어만 표시해요. 부분 문자열·이니셜은 쓰지 않아요.
        if len(source_words) == 1 and not source_initials and source_words[0] in words:
            return True
        target_initials = {normalize_identity_text(x) for x in re.findall(r"\b([^\W\d_])\.", value)}
        # Þ.·Đ.는 정규화하면 th·dj 두 글자예요. 원문에서 마침표가 붙은 이니셜만 허용해요.
        # Gaspar처럼 DB 쪽이 이니셜인 경우에도 같은 경기·팀·등번호 조건은 유지해요.
        def same(a, b):
            return a == b or (a in source_initials and b.startswith(a)) or (b in target_initials and a.startswith(b))

        # 이름 순서가 다르거나 Zabi·Nagida처럼 앞·중간 이름이 생략돼요.
        # 두 단어 이상을 정확히 대조하고, 전체 이름부터 골라 이니셜의 중복 연결을 막아요.
        if 2 <= len(source_words) <= len(words):
            remaining_words = list(words)
            for word in sorted(source_words, key=lambda w: w in source_initials):
                candidates = [w for w in remaining_words if same(word, w)]
                if len(candidates) != 1:
                    break
                remaining_words.remove(candidates[0])
            else:
                return True

        # Toulouse–Lille의 C. Cásseres, H. Haraldsson, Alexsandro Ribeiro는 중간 이름도 생략해요.
        # 첫 이름은 같아야 하고, 나머지는 원래 순서의 정확한 단어여야 해요. 유사도는 쓰지 않아요.
        if len(source_words) >= 2 and words and same(source_words[0], words[0]):
            remaining = iter(words[1:])
            if all(any(same(word, candidate) for candidate in remaining) for word in source_words[1:]):
                return True
    return False


def match_roster(players: list[dict], rows: list[dict]) -> dict:
    matches = {}
    for player in players:
        # Roth와 Strannegård처럼 공급자 명단에 같은 번호가 중복돼도 이름까지 일치해야 해요.
        candidates = [row for row in rows if (row["jersey_number"] == player["jersey_number"]
                      or SHIRT_NUMBER_ALIASES.get((row["fixture_id"], row["player_id"])) == player["jersey_number"])
                      and player_name_matches(player["name"], row)]
        if len(candidates) == 1:
            matches[player["external_player_id"]] = candidates[0]["player_id"]
    return matches


def plan_match_ids(raw: dict, match: dict, fixtures: list[dict], lineups: list[dict], known: dict) -> dict:
    if raw["match_id"] != match["external_fixture_id"]:
        raise ValueError("일정과 수집 화면의 경기 ID가 달라요.")
    if datetime.strptime(raw["match_date"], "%A %d %B %Y").date().isoformat() != match["date"]:
        raise ValueError("일정과 경기 화면의 날짜가 달라요.")
    for side in ("home", "away"):
        if raw["teams"][side]["external_team_id"] != match[f"{side}_external_team_id"]:
            raise ValueError("일정과 경기 화면의 홈·원정 팀이 달라요.")

    candidates = [f for f in fixtures if str(f["starting_at"])[:10] == match["date"]]
    candidate_ids = {f["fixture_id"] for f in candidates}
    if candidates and not any(p["fixture_id"] in candidate_ids for p in lineups):
        raise ValueError("DB 출전 명단이 없어요. 대상 경기의 fixture-details 적재를 먼저 진행해 주세요.")
    verified = []
    for fixture in candidates:
        matched = {}
        for side, team in raw["teams"].items():
            rows = [p for p in lineups if p["fixture_id"] == fixture["fixture_id"]
                    and p["team_id"] == fixture[f"{side}_team_id"]]
            matched[side] = match_roster(team["players"], rows)
        # Opta는 독일 경기 선수 전원을 이니셜로 표기해요. 시즌 전체 이름 집합을 비교하는
        # Understat 방식과 달리, 같은 날짜·홈/원정·실제 등번호까지 대조한 양 팀 각 3명이 필요해요.
        if all(len(matched[side]) >= 3 for side in ("home", "away")):
            verified.append((fixture, matched))
    if len(verified) != 1:
        raise ValueError(f"날짜·양 팀 명단으로 경기를 유일하게 연결하지 못했어요: {[f['fixture_id'] for f, _ in verified]}")
    fixture, matched = verified[0]
    teams = {team["external_team_id"]: fixture[f"{side}_team_id"] for side, team in raw["teams"].items()}
    mapped_fixtures = {raw["match_id"]: fixture["fixture_id"]}
    players, pending = {}, []
    for side, team in raw["teams"].items():
        players.update(matched[side])
        for player in team["players"]:
            if player["external_player_id"] not in matched[side]:
                pending.append({**player, "team_id": fixture[f"{side}_team_id"]})
    planned = {"team": teams, "fixture": mapped_fixtures, "player": players}
    for entity, mapping in planned.items():
        for external, internal in mapping.items():
            if external in known[entity] and known[entity][external] != internal:
                raise ValueError(f"기존 {entity} ID와 이번 경기 근거가 달라요: {external}")
        validate_external_id_uniqueness(f"Opta {entity}", {**known[entity], **mapping})
    return {"fixture": fixture, "mappings": planned, "pending_players": pending,
            "roster_matches": {side: len(ids) for side, ids in matched.items()}}
