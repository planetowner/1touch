from __future__ import annotations

import os
import time
from datetime import date
from typing import Dict, Iterable, List, Optional
from urllib.parse import parse_qsl, urlparse

import requests
from dotenv import load_dotenv


load_dotenv()


# 공식 명단·다른 경기 응답·선수 단건 프로필로 확인한 라인업 ID만 보정해요.
SPORTMONKS_LINEUP_PLAYER_ID_OVERRIDES = {
    # Malisheva의 18·33·55번은 UEFA 명단·단건 프로필·현재 소속 ID를 대조했어요.
    # 이름이 비슷한 선수를 찾지 않고, 확인한 예선 네 경기의 null 슬롯만 복원해요.
    # https://www.uefa.com/uefaconferenceleague/clubs/2611789--malisheva/squad/
    14674133845: 31884,     # Nafiu, Vllaznia 원정
    14674188778: 31884,     # Nafiu, Hibernian 홈
    14674233915: 31884,     # Nafiu, Hibernian 원정
    14674134074: 37948507,  # Murati, Vllaznia 원정
    14674146680: 37948507,  # Murati, Vllaznia 홈
    14674188774: 37948507,  # Murati, Hibernian 홈
    14674233918: 37948507,  # Murati, Hibernian 원정
    14674134075: 37612096,  # Shani, Vllaznia 원정
    14674146681: 37612096,  # Shani, Vllaznia 홈
    14674188749: 37612096,  # Shani, Hibernian 홈
    14674233778: 37612096,  # Shani, Hibernian 원정
    # Vllaznia 44번은 UEFA의 생년월일(2009-02-06)·등번호와 두 교체 기록이 일치해요.
    # https://www.uefa.com/uefaconferenceleague/clubs/players/250216015--sokol-uldedaj/
    14674134079: 38216439,
    14674146657: 38216439,
    # RFS 7번 Diomande는 구단 명단·32분 교체·현재 스쿼드의 ID로 확인했어요.
    # https://fkrfs.lv/en/player/ismael-diomande/?tid=20
    14674133977: 37621044,
    # Santa Coloma 22번은 88분 교체의 전체 이름과 7월 입단 프로필을 대조했어요.
    # Rapid 원정에는 2009년생 Alex의 ID가 섞였어요. 확인한 2003년생 Alejandro로 네 슬롯을 맞춰요.
    # https://www.soccerzz.com/live/2026-07-09-penybont-fc-santa-coloma/12249336
    14674134142: 37718055,
    14674157918: 37718055,
    14674190008: 37718055,
    14674228328: 37718055,
    # Víkingur 8번은 UEFA 생년월일·등번호와 다음 경기의 같은 ID를 확인했어요.
    # https://www.uefa.com/uefaconferenceleague/clubs/players/250138543--aron-ellingsgaard/
    14674134173: 37336173,
    # Sarajevo 23번은 협회 기록의 73분 교체와 다음 경기·현재 소속 프로필이 일치해요.
    # https://www.nfsbih.ba/en/news/football-m/wwin-league-bh/sarajevo-draws-with-inter-turku/
    14674134391: 37956563,
    # Caernarfon 8번은 첫 경기·현재 스쿼드의 Gosset ID와 58분 교체를 대조했어요.
    14674157625: 9136,
    # Liepāja 77번은 협회 생년월일(2005-05-19)·현재 소속·다음 경기 ID로 확인했어요.
    # https://lff.lv/klubi/fk-liepaja-38387/?cid=23300000
    14674188868: 37597766,
    # Cody David는 Korede Adedoyin의 변경된 이름이에요. 리그 기사·LNZ 이적·다음 경기 99번을 대조했어요.
    # https://www.veikkausliiga.com/uutiset/2025/03/08/ifk-mariehamn-testaa-hyokkaajaa-englannista-teki-vaikutuksen-heti-ensimmaisissa-harjoituksissa
    14674190799: 28912852,
    # Ilves 19번 Bamba·33번 Sacko는 공식 생년월일·번호와 다른 경기 ID로 확인했어요.
    # https://www.veikkausliiga.com/pelaajat/1297827/bamba-abdoul-goudousse
    # https://www.uefa.com/news-media/mediaservices/informationkits/competitions/uefaconferenceleague/2027/match/2048666/printmatchpresskits/
    14674191170: 37758057,
    14674231643: 37758057,
    14674276558: 38218740,
    # Koper 26번은 UEFA 생년월일과 7월 이적·현재 스쿼드 ID를 대조해 두 슬롯의 ID·프로필을 맞춰요.
    # https://www.uefa.com/under19/teams/players/250215178--benjamin-adrovic/
    14674191063: 38218953,
    14674233881: 38218953,
    # Inter의 31번은 Mali 출신 Souleymane(1999-04-02)이에요. 프랑스 동명이인·Sol이 섞였어요.
    # UEFA 명단·현재 소속·7월 이적·다음 두 경기 31번을 대조한 Flora전 두 슬롯만 복원해요.
    # https://www.uefa.com/nationalassociations/teams/63401--inter-escaldes/squad/
    14674275555: 37263359,
    14674332844: 37263359,
    # Mondorf의 Dinamo전 두 경기 72번 Tinelli·77번 Klica는 ID·프로필이 null이에요.
    # UEFA 경기 명단·교체 기록과 현재 소속의 선수 ID를 대조했어요. 현재 등번호로 대체하지 않아요.
    # https://ar.uefa.com/uefaconferenceleague/clubs/2603085--mondorf/squad/
    14674133481: 538864,   # 1차전 19719451, 72번
    14674133483: 2178606,  # 1차전 19719451, 77번
    14674157729: 538864,   # 2차전 19719425, 72번
    14674157731: 2178606,  # 2차전 19719425, 77번
    # Bohemians전(19719458) 후보 13번 Romero가 null이라 64분 골키퍼 교체 FK가 실패했어요.
    # 현장 기록·다음 경기 13번·단건 생년월일을 대조한 이 슬롯만 복원해요.
    # https://www.rte.ie/sport/soccer/2026/0709/1582658-bohemians-toil-to-victory-on-european-return/
    14674133663: 379230,
    # Milsami의 Velez전 두 경기 4번 Angelov·7번 Silcenco·17번 Bulmaga는 ID·프로필이 null이에요.
    # 협회 명단·39분 경고·90+1분 교체와 현재 스쿼드의 팀·번호·선수 ID를 대조했어요.
    # https://fmf.md/noutate/18029/liga-conferintei-velez-mostarmilsami-11
    # Angelov의 UEFA 생일은 단건 응답과 달라, 선수 식별과 별개로 기존 공급자 값을 유지해요.
    14674133204: 528152,    # 1차전 19719456, 4번
    14674133617: 37721425,  # 1차전 19719456, 17번
    14674133612: 38213137,  # 1차전 19719456, 7번
    14674157930: 528152,    # 2차전 19719430, 4번
    14674158012: 37721425,  # 2차전 19719430, 17번
    14674158008: 38213137,  # 2차전 19719430, 7번
    # La Fiorita의 Strassen전 두 선발 17번 Djuric도 ID·프로필이 null이에요.
    # 협회 프로필의 생년월일(1992-09-18)·UEFA 등번호·2차전 교체와 경고를 대조했어요.
    # https://www.fsgc.sm/it/giocatore/djuric-marco/943
    14674130710: 435952,  # 1차전 19719435
    14674145202: 435952,  # 2차전 19719409
    # Strassen의 La Fiorita전 두 경기 후보 17번 Teixeira는 ID·프로필이 null이에요.
    # 공식 명단·단건 생년월일과 다음 Partizan 두 경기의 17번 ID를 대조했어요.
    # https://de.uefa.com/uefaconferenceleague/clubs/2603092--una-strassen/squad/
    14674130745: 21404660,  # 1차전 19719435
    14674145259: 21404660,  # 2차전 19719409
    # Sassuolo–Cesena(19728352)의 18번 Guidi가 산마리노 동명이인(2003-01-15)으로 연결됐어요.
    # 구단 경기 기록·공식 명단의 이탈리아 선수(2003-07-03)와 직전 시즌 18번을 대조했어요.
    # https://www.cesenafc.com/it/teams/prima-squadra/news/sassuolo-cesena-3-0-2026-08-17
    # https://www.sampdoria.it/wp-content/uploads/2026/04/2025-26_cesena-sampdoria_match_program.pdf
    14674391794: 37655935,
    # Anderlecht 예선 6경기의 후보 53번 Ojea는 이름만 있고 선수 ID·프로필이 null이에요.
    # Kairat전 두 교체 ID와 벨기에 협회 명단의 소속·생년월일(2009-08-10)을 대조했어요.
    # https://belgianfootball.s3.eu-central-1.amazonaws.com/s3fs-public/rbfa/docs/pdf/selections/u15_futures/squadlist_U15F_050224.pdf
    14674189866: 37749100,  # Hammarby 1차전 19720999
    14674233251: 37749100,  # Hammarby 2차전 19720989
    14674276156: 37749100,  # PAOK 1차전 19766398
    14674334019: 37749100,  # PAOK 2차전 19766393
    14674406816: 37749100,  # Kairat 1차전 19788667
    14674478828: 37749100,  # Kairat 2차전 19788658
    # Benfica와의 두 경기 후보 24번 Kamson-Kamara의 ID·프로필이 null로 왔어요.
    # 구단 명단·다음 두 경기의 24번·단건 생년월일로 확인한 슬롯만 복원해요.
    # https://www.heartsfc.co.uk/blogs/news/match-report-hearts-1-1-benfica
    14674276761: 37675238,  # 1차전 19766404
    14674334370: 37675238,  # 2차전 19766390
    # Sheriff–Aluminij(19719405) 선발 42번 Loukou의 ID·프로필이 null로 왔어요.
    # 같은 경기 교체 이벤트·다음 5경기의 42번·단건 프로필이 일치한 슬롯만 복원해요.
    14674133376: 37727159,
    # UEFA 명단의 후보 32번 Ross가 Matthew Clarke(149243)로 잘못 연결돼 있어요.
    6955752879: 148658,  # La Fiorita전 1818661
    4321876: 148658,  # Celtic전 2457629: details.player_id도 Ross를 가리켜요.
    # Chelsea전 16943119의 후보 19번은 PL 공식 명단의 José Izquierdo예요.
    # 29번 Zeqiri(199544)와 중복된 이 자리만 바로잡아요.
    143428: 62408,
    # Leverkusen전 16840330의 후보 8번은 DFB·Bayern 명단의 Javi Martínez예요.
    # 18번 Goretzka(31824)로 잘못 연결된 자리이며, 다음 4경기도 Javi의 ID를 확인했어요.
    142293: 31686,
    # Cádiz–Real Sociedad(18545093)의 후보 28·35번은 구단 명단의 Curro·Kikín이에요.
    # 28번 details.player_id와 35번 다음 경기(18545107)도 각각 같은 ID를 확인해요.
    # https://www.cadizcf.com/partidos/temporada-2022-2023-laliga-santander-1-cadiz-cf-vs-real-sociedad
    79284464: 37608061,
    7250503808: 37614327,
    # Getafe–Villarreal(18545112)의 후보 30·31·32번이 모두 Christo Vela로 잘못 연결됐어요.
    # 구단 명단의 Moi·Revuelta·Alex와 직전 두 경기의 ID·단건 프로필을 대조했어요.
    # https://www.getafecf.com/partidos/temporada-2022-2023-laliga-ea-sports-3-getafe-cf-vs-villarreal-cf
    6685486486: 37592616,
    6685486116: 37308357,
    6685486219: 37543847,
    # Atlético–Elche(18545229)의 후보 32·33번은 구단 명단의 Alfaro·Cocca예요.
    # 32번 details.player_id와 33번 다음 경기(18545245)도 같은 ID를 확인해요.
    # https://www.elchecf.es/partidos/temporada-2022-2023-laliga-santander-15-atletico-de-madrid-vs-elche-cf
    1011309558: 37590132,
    7250492567: 37598694,
}

# Rexhaj는 81분 교체·88분 퇴장의 ID와 UEFA 명단의 이름·6번을 대조했어요.
# 단건·스쿼드에 프로필이 없어, 사용자와 합의한 이 슬롯만 ID·이름으로 등록해요.
# 국적·생일·포지션 등 미제공 정보는 채우지 않아요. 근거: FIXTURE_DETAILS_REVIEW.md
# https://www.uefa.com/uefaconferenceleague/clubs/2608311--dukagjini/squad/
SPORTMONKS_LINEUP_PLAYER_PROFILE_OVERRIDES = {
    14674190712: {
        "id": 37763035,
        "name": "Arvanit Rexhaj",
        "display_name": "Arvanit Rexhaj",
    },
}

# 실제 교체와 프로필을 확인했지만 라인업 행이 아예 없는 이벤트만 보충해요.
SPORTMONKS_EVENT_PLAYER_PROFILE_IDS = {
    # Motherwell–HB의 78분 교체 선수는 확인되지만 첫 경기 라인업에 17번 행 자체가 없어요.
    # 다음 경기 17번·현재 소속·실제 교체를 대조한 이 이벤트의 프로필만 보충해요.
    # https://www.footballwebpages.co.uk/match/2026-2027/uefa-conference-league/motherwell/hb-torshavn/574647
    157313260: 6234,
    # Pafos–Salzburg(19766394): 중계·다음 두 경기 33번·단건 생년월일을 대조했어요.
    # https://sport.sky.de/fussball/pafos-vs-salzburg/live/571443
    157460319: 226852,
    # Partizan–Tobol(19766274): 68분 Lisakovich 교체는 있지만 후보 99번 행이 없어요.
    # 중계·다음 경기 99번·UEFA의 생년월일(1998-02-08)을 대조했어요. 라인업은 만들지 않아요.
    # https://www.skysports.com/football/partizan-belgrade-vs-tobol-kostanay/577228
    157401474: 58436,
}

# 원문과 검증한 경기 기록을 대조해 잘못된 이벤트 필드만 보정해요.
SPORTMONKS_EVENT_OVERRIDES = {
    # Rapid 원정의 22번은 다른 세 경기·현재 스쿼드와 같은 Gómez예요. 해당 경기의 다른 ID만 맞춰요.
    157351480: {"related_player_id": 37718055},
    157351924: {"related_player_id": 37718055},
    157351961: {"player_id": 37718055},
    # Flora전의 도움·교체도 확인한 Mali 출신 31번으로 연결하고 기록 내용은 보존해요.
    157400422: {"related_player_id": 37263359},
    157459646: {"related_player_id": 37263359},
    157459733: {"related_player_id": 37263359},
    157459772: {"related_player_id": 37263359},
    # Raków 경고의 두 Gaucho 프로필은 생년월일이 같아요. 예선 5경기 라인업의 ID로 이 카드만 연결해요.
    # https://pt.uefa.com/uefaconferenceleague/clubs/players/250222734--debohi-dieudonne-gaucho/
    157460575: {"player_id": 37569232},
    # Riga전 벤치 경고의 Fabbiani는 Vardar 감독이에요. 같은 경기 감독의 ID·팀과 UEFA 명단을 대조했어요.
    # https://www.uefa.com/uefaconferenceleague/clubs/53080--vardar/squad/
    157348954: {"player_id": None, "coach_id": 163293, "participant_id": 5492},
    # Shkëndija 예선 4경기의 Krasniqi 이벤트만 Blendrit 프로필(37664368)로 잘못 연결됐어요.
    # UEFA의 10번·생년월일과 구단·협회 경기 기록, 예선 6경기 라인업의 Endrit(1068604)을 대조했어요.
    # https://www.uefa.com/news-media/mediaservices/informationkits/competitions/uefaconferenceleague/2026/match/2046365/
    # https://www.nzs.si/podrocja/novinarji/novice/bravo-s-preobratom-do-prednosti-382255
    157253906: {"related_player_id": 1068604},  # Europa 원정 28분 도움
    157281256: {"player_id": 1068604},          # Europa 홈 71분 경고
    157312629: {"player_id": 1068604},          # Bravo 원정 11분 페널티킥 득점
    157312638: {"player_id": 1068604},          # Bravo 원정 13분 경고
    157313188: {"related_player_id": 1068604},  # Bravo 원정 69분 교체 아웃
    157355767: {"player_id": 1068604},          # Bravo 홈 66분 교체 투입
    # Milsami–Velez(19719430) 86분 교체의 Silcenco ID 37721430은 단건 data가 없어요.
    # 협회 경기 명단·생년월일·현재 스쿼드 7번과 이적 기록으로 확인한 ID만 연결해요.
    # https://www.fmf.md/noutate/18088/liga-conferintei-milsami-sia-incheiat-parcursul-european
    # https://fmf.md/noutate/17953/liga-7777-loturile-echipelor
    157280997: {"player_id": 38213137},
    # Strassen–Partizan(19720917) 85분 교체만 Marinković의 다른 ID 38217824를 써요.
    # 현장 기록·구단 원정 명단·같은 생년월일(2009-02-14)의 후보 66번을 대조했어요.
    # https://partizan.rs/en/vesti/5385/crno-beli-krenuli-u-luksemburg
    # https://sportklub.rs/fudbal/europa-conference-league/una-partizan-revans-utakmica-drugog-kola-lige-konferencije-sastavi-izvestaj-strelci/
    157356069: {"player_id": 37788791},
    # La Fiorita전 Seye의 교체·도움은 UEFA의 44번·2003-09-18 생년월일과 일치해요.
    # 이벤트의 다른 생년월일 ID(37776409) 대신 세 경기 라인업의 37708770을 써요.
    # https://es.uefa.com/uefaconferenceleague/clubs/players/250221520--babou-seye/
    157250422: {"player_id": 37708770},
    157272490: {"related_player_id": 37708770},
    157273053: {"related_player_id": 37708770},
    # Teixeira의 88·69분 교체는 협회 기록과 같지만 이벤트만 다른 프로필 ID를 써요.
    # 같은 생년월일(1996-05-07)·다음 두 경기 17번으로 확인한 ID에 두 교체를 연결해요.
    # https://www.fsgc.sm/it/notizia/european-cups-narrow-defeats-for-tre-fiori-and-la-fiorita/2271
    # https://www.fsgc.sm/it/notizia/coppe-europee-una-strassen-dautorit-su-la-fiorita-il-tre-fiori-spaventa-il-larne-/2276
    157250485: {"player_id": 21404660},
    157272982: {"player_id": 21404660},
    # Craiova전(19788665) 63분 VAR만 Sandro Lima의 다른 ID 159536을 사용했어요.
    # UEFA의 91번·생년월일과 예선 8경기 라인업이 일치하는 37640040으로 이 이벤트만 연결해요.
    # https://de.uefa.com/uefachampionsleague/clubs/players/250086826--sandro-lima/
    157569490: {"player_id": 37640040},
    # Cluj의 Kyiv전 92분·Brann전 61분 교체는 구단 기록과 라인업의 Dan Nistor(96351)예요.
    # 이름만 Dan으로 붙은 Raul Nistor(37600520)의 ID를 두 이벤트에서만 바로잡아요.
    # https://www.fcucluj.ro/stire/cronica-u-cluj-vs-dinamo-kiev-0-0-2-4-la-lovituri-de-departajare-continuam-in-conference-league
    # https://www.fcucluj.ro/stire/cronica-u-cluj-vs-sk-brann-2-2-final-spectaculos-la-sfantu-gheorghe-totul-se-decide-in-norvegia
    157281284: {"player_id": 96351},
    157312228: {"related_player_id": 96351},
    # Crvena–Hapoel(19766300)의 57분 퇴장은 선수 출신 Stanković 감독의 카드예요.
    # 같은 경기 coaches의 ID·팀과 현장 기록이 일치해 선수 FK만 비워요.
    # https://hotsport.rs/2026/08/11/stankovic-crveni-karton-navijaci/
    157450859: {"player_id": None, "coach_id": 127597},
    # Slovan–Iberia(19721243)의 84분 투입 선수는 UEFA 기록의 후보 24번 Tomáško예요.
    # 같은 생년월일의 두 공급자 ID 중 이 경기·다른 두 경기 라인업 ID로 연결해요.
    # https://www.uefa.com/news-media/mediaservices/informationkits/competitions/uefachampionsleague/2027/match/2048737/
    157351936: {"player_id": 37788117, "player_name": "Matúš Tomáško"},
    # Sutjeska–Kairat(19719878)의 경고·교체 아웃 선수는 선발 77번 Šimun(37683336)이에요.
    # FSCG 프로필·다른 3경기의 같은 선수 ID를 확인했어요. Simunovikj가 섞인 34907293은 쓰지 않아요.
    # https://fscg.me/en/players/marko-simun-113281/
    # https://www.bdfutbol.com/en/p/p.php?id=403888
    157274758: {"player_id": 37683336},
    157274880: {"related_player_id": 37683336},
    # KÍ의 아래 득점·도움은 경기 보도·선발 명단의 Árni(86656)가 기록했어요.
    # Andras(86653)로 잘못 연결된 이벤트만 보정해요. 다른 경기의 ID는 바꾸지 않아요.
    # https://www.roysni.fo/foroyameistararnir-hava-fyrimunin-eftir-fyrra-dystin
    # https://www.roysni.fo/video-arni-og-pall-snyta-malverjan-og-allar-hinar
    # https://nordlysid.fo/tvey-kedilig-mal-sendu-ki-ut/
    157250665: {"related_player_id": 86656, "related_player_name": "Árni Frederiksberg"},
    157274524: {"player_id": 86656, "player_name": "Árni Frederiksberg"},
    157274780: {"related_player_id": 86656, "related_player_name": "Árni Frederiksberg"},
    157652206: {"related_player_id": 86656, "related_player_name": "Árni Frederiksberg"},
    # Girona–Espanyol(10420711) 89분 해설 3378984의 패스 선수는 Javi López예요.
    # 무관한 Julián López(107746) 대신 같은 경기 라인업·단건 프로필의 ID를 써요.
    32722265: {"related_player_id": 185640, "related_player_name": "Javi López"},
    # Stuttgart–Köln(18156897)의 Matarazzo 경고는 DFB 기록상 90+6분이에요.
    # 원문의 -4분만 바로잡고, 다른 음수 시각은 추정해서 변환하지 않아요.
    # https://datencenter.dfb.de/datencenter/bundesliga/2021-22/34/vfb-stuttgart-1-fc-koeln-2327777
    84175108: {"minute": 90, "extra_minute": 6},
    # Strasbourg–Nice(18160992) Galtier의 경고는 구단 공식 기록상 50분이에요.
    # https://www.ogcnice.com/fr/live/1892/strasbourg-nice.html
    67695281: {"minute": 50},
    # Spurs–Brighton(18535379) 59분 퇴장은 선수 Yallop(333528)이 아닌 Stellini 감독이에요.
    # 감독 프로필의 Tottenham 재임 기간은 2023-03-26~04-23이에요. 선수 FK는 비워요.
    # https://www.gettyimages.co.uk/detail/news-photo/referee-stuart-attwell-shows-a-red-card-to-cristian-news-photo/1480818499
    82392114: {"player_id": None, "player_name": "Cristian Stellini", "coach_id": 128374, "on_bench": True},
    # Sevilla–Cádiz(18545266): Sampaoli는 59분에 연속 경고로 퇴장했어요(RTVE 경기 기록).
    # 원문의 첫 경고도 59분이며, -4분으로 잘못 온 두 번째 경고 시각만 보정해요.
    # https://www.rtve.es/deportes/20230121/sevilla-cadiz-liga-resumen/2416768.shtml
    83630899: {"minute": 59},
    # 2024/25 해설 8726917·8742564·8792466은 Evans·Armstrong·Walker-Peters의 경고예요.
    # 잘못 붙은 관련 감독만 비워요. 각 감독의 별도 경고 이벤트는 응답에 있어요.
    122078701: {"related_player_id": None, "related_player_name": None},
    122524819: {"related_player_id": None, "related_player_name": None},
    147078403: {"related_player_id": None, "related_player_name": None},
    # Bayern–Leverkusen(19154581)은 감독 경고 뒤로 선수 이름이 한 칸씩 밀렸어요.
    # DFL의 Alonso 23분과 해설 8700154·8700358·8700454의 선수·시각을 대조했어요.
    # https://www.bundesliga.com/en/bundesliga/matchday/2024-2025/5/fc-bayern-muenchen-vs-bayer-04-leverkusen/liveticker
    120944080: {"player_id": None, "player_name": "Xabi Alonso", "related_player_id": None, "related_player_name": None, "coach_id": 511},
    120947307: {"player_id": 34880, "player_name": "Robert Andrich"},
    120948914: {"player_id": 37429246, "player_name": "Florian Wirtz"},
    156753719: {"player_id": 160208, "player_name": "Alejandro Grimaldo"},
    # Genoa–Bologna(19155140)도 Gilardino 41분 뒤의 선수 경고가 밀렸어요.
    # 현장 기록과 해설 8726420·8726841로 Aaron 64분·Pinamonti 86분을 확인했어요.
    # https://www.pianetagenoa1893.net/primo-piano/genoa-bologna-2-2-finale-live-match/
    122074904: {"player_id": None, "player_name": "Alberto Gilardino", "related_player_id": None, "related_player_name": None, "coach_id": 127771},
    122077840: {"player_id": 186983, "player_name": "Aarón Martín"},
    156506028: {"player_id": 134034, "player_name": "Andrea Pinamonti"},
    # Genoa–Inter(19155070) 90+9분 경고는 Guan He가 아닌 Asllani예요.
    # Inter 공식 기록·해설 8636536·같은 경기 선수 ID를 대조했어요.
    # https://www.inter.it/en/match_center/5248
    118335581: {"player_id": 37532950, "player_name": "Kristjan Asllani"},
    # Napoli–Parma(19155094) 해설 8657198의 교체 아웃 선수는 Kowalski예요.
    # Mike West(8452) 대신 같은 경기 선발 62번의 내장 프로필 ID를 써요.
    119207638: {"related_player_id": 37634619, "related_player_name": "Mateusz Kowalski"},
    # Genoa–Roma(19155101)의 Guan He 71분 경고는 현장 기록의 Gilardino 감독이에요.
    # https://www.vocegiallorossa.it/tabellini/genoa-roma-1-1-de-winter-a-segno-all-ultimo-respiro-non-basta-il-primo-gol-di-dovbyk-258916
    150631481: {"player_id": None, "player_name": "Alberto Gilardino", "coach_id": 127771},
    # Juventus–Napoli(19155112) 58분 경고는 Lliuya가 아닌 Motta 감독이에요.
    # https://www.corrieredellosport.it/news/calcio/serie-a/2024/09/21-133066531/juve-napoli_diretta_conte_torna_allo_stadium_segui_la_partita_live
    156760411: {"player_id": None, "player_name": "Thiago Motta", "coach_id": 95726},
    # Torino–Lazio(19155125)는 Vanoli의 경고와 퇴장이 모두 있어 두 건을 남겨요.
    # Lazio 공식 기록상 둘 다 75분이에요. 원문의 퇴장 74분만 바로잡아요.
    # https://www.sslazio.it/en/news/match-report/serie-a-enilive-or-torino-lazio-le-formazioni-ufficiali
    150631490: {"player_id": None, "coach_id": 37610194},
    156760412: {"minute": 75},
    # 아래 경고·퇴장 ID는 각 경기 coaches의 ID·팀과 일치하는 감독이에요.
    # 선수로 적재하지 않고 감독으로 구분해요. 시각·카드 종류·벤치 표시는 유지해요.
    149315420: {"player_id": None, "coach_id": 29676},  # Frankfurt–Union: Baumgart
    149406420: {"player_id": None, "coach_id": 511},  # Stuttgart–Leverkusen: Alonso
    121051984: {"player_id": None, "coach_id": 459054},  # Nantes–Saint-Étienne: Kombouaré
    156504811: {"player_id": None, "coach_id": 456014},  # Nantes–Rennes: Sampaoli
    156506029: {"player_id": None, "coach_id": 37610194},  # Cagliari–Torino: Vanoli
    148707483: {"player_id": None, "coach_id": 95726},  # Torino–Juventus: 선수 이력이 있는 Motta도 감독이에요.
    148859933: {"player_id": None, "coach_id": 455384},  # Atalanta–Napoli: Conte
    148874121: {"player_id": None, "coach_id": 128160},  # Lecce–Inter: Inzaghi
    156773864: {"player_id": None, "coach_id": 452946},  # Sociedad–Atlético: Simeone
    148821172: {"player_id": None, "coach_id": 456423},  # Villarreal–Mallorca: Arrasate
    149166691: {"player_id": None, "coach_id": 456423},  # Sevilla–Mallorca: Arrasate
    # Getafe–Valladolid(19135381): Pezzolano는 전반 종료 전 경고 두 번으로 퇴장했어요.
    # 기존 45+1분·45+4분 행을 감독에게 연결하고 잘못 중복된 61분 행은 제외해요.
    # https://www.realvalladolid.es/noticias/2-0-pucela-cae-getafe
    156504056: {"player_id": None, "player_name": "Paulo Pezzolano", "coach_id": 186071},
    156504059: {"coach_id": 186071},
    # Milan–Como(19155351)의 Conceição 경고는 Milan 공식 기록의 후반 37분이에요.
    # https://www.acmilan.com/it/news/articoli/serie-a/2025-03-15/milan-ancora-di-rimonta-sul-como-2-1
    150631537: {"minute": 82},
    # Napoli–Milan(19155365) 두 중복 행의 72·76분은 현장 기록의 71분으로 보정해요.
    # Conte의 별도 경고는 76분이에요. https://www.gazzetta.it/Calcio/Serie-A/Napoli/30-03-2025/napoli-milan-formazioni-live-diretta-serie-a.shtml
    149544682: {"minute": 71},
    # Inter–Lazio(19155431): Inter 공식 기록상 88분에 두 감독이 각각 퇴장했어요.
    # https://www.inter.it/en/match_center/5284
    150424045: {"player_id": None, "coach_id": 455848},
}

# 공식 기록·공급자 해설로 중복을 확인한 이벤트 ID만 제외해요.
SPORTMONKS_DUPLICATE_EVENT_IDS = {
    # Kluivert의 -4분 퇴장은 해설 4840734와 일치하는 85분 이벤트 78696510과 중복돼요.
    67695288,
    # Perrin의 경고는 해설 4840704에서 한 번이에요. 저장값이 같은 29992706을 남겨요.
    29992873,
    # Salernitana–Cagliari(18220215): FIGC 결정문은 두 선수의 벤치 퇴장을 확인해요.
    # https://www.figc.it/media/166393/sez-i-decisione-n-310-csa-del-23-maggio-2022.pdf
    # Radunović의 -4분 행 대신 후반 24분 사건에 해당하는 78866603을 남겨요.
    67945179,
    # Ribéry의 선수 ID 없는 55분 행 대신 해설 41214와 일치하는 78866604를 남겨요.
    67945141,
    # Brighton–Forest(19134484): PL 공식 기록의 두 감독 퇴장은 각각 한 건이에요.
    # 선수 FK로 잘못 온 Hürzeler와 감독 ID 없는 Nuno의 중복만 제외해요.
    # 감독 ID가 있는 120554621·120573201을 남겨요. https://www.premierleague.com/en/news/4126263
    149481174,
    149481175,
    # 아래는 같은 경기·팀·감독·카드·시각으로 중복된 선수 FK 행이에요.
    # 각 주석의 감독 ID가 있는 이벤트를 남겨요. 경기별 원문은 2024/25 FK 점검 로그에 있어요.
    149815615,  # Bournemouth–West Ham: Lopetegui 152525300
    150118463,  # Mainz–Leverkusen: Alonso 150119575
    156504818,  # Le Havre–Reims: Digard 123452452
    148907990,  # Montpellier–Lens: 이름도 잘못된 Still(5961878), 156351613 유지
    148707482,  # Torino–Juventus: Vanoli 150631518; Motta의 별도 퇴장은 유지해요.
    149018393,  # Inter–Fiorentina: Inzaghi 150631529
    149290112,  # Lecce–Milan: Conceição 156760421
    150422283,  # Parma–Napoli: Conte 150422536; 16분 첫 경고는 유지해요.
    150422333,  # Roma–Milan: Conceição 150424046
    150483273,  # Venezia–Juventus: Tudor 150483228
    156504092,  # Mallorca–Girona: Arrasate 147807041
    148792648,  # Atlético–Osasuna: Simeone 156351529
    149055890,  # Osasuna–Real Madrid: Ancelotti 156514945
    149542208,  # Valencia–Mallorca: Arrasate 156773944
    # Inter–Como(19155231) 63분은 Fàbregas 경고 한 건이에요. 150631510을 남겨요.
    # 무관한 Ehrenberg가 연결된 중복이에요. https://www.passioneinter.com/inter-news/cronaca-inter-como-diretta/
    148466268,
    # 위 공식 기록과 대조한 Pezzolano의 61분 중복 경고예요.
    146723373,
    # Milan–Como는 Conceição 경고 한 건과 Fàbregas 퇴장 한 건이에요.
    # 150631536도 이름만 Fàbregas이고 팀·감독 ID는 Conceição인 중복이에요.
    149378330,
    150631536,
    # Napoli–Milan: Conceição 감독 ID가 있는 149544682만 남겨요.
    149546873,
    # Inter–Lazio: Inzaghi의 동일한 88분 퇴장 150422179를 남겨요. Baroni도 유지해요.
    150422294,
    # 2025/26의 아래 ID는 감독 이름·선수 FK가 추가된 중복 경고예요.
    # 경기별 coaches·해설·기존 감독 카드를 대조했어요. 정상 선수 카드는 모두 남겨요.
    # 시각·팀까지 잘못 복제된 행이 있어 값으로 자동 판정하지 않고 확인한 ID만 제외해요.
    # 근거: logs/diagnostics/fixture-event-player-fk/remaining-2025-2026-after-64/
    # Chelsea–Liverpool의 82분은 Slot이에요. Maresca의 기존 40분 경고도 유지해요.
    # https://www.besoccer.com/new/chelsea-v-liverpool-as-it-happened-1376054
    151652229,  # 19427519: Slot 151652283 유지
    151996655,  # 19427550: Emery 152525327 유지
    152173697,  # 19427569: Maresca 152173903 유지
    152435270,  # 19427628: Parker 152435144 유지
    152476119,  # 19427656: Arteta 152476113 유지
    152474262,  # 19427659: Parker 152474261 유지
    152473721,  # 19427662: Silva 152473472 유지
    152539264,  # 19427669: Silva 152536616 유지
    152665956,  # 19427691: Silva 152663747 유지
    152669239,  # 19427694: Guardiola 152669071 유지
    152741347,  # 19427710: Iraola 152741349 유지
    152746503,  # 19427711: Guardiola 152746478 유지
    156657243,  # 19427734: Guardiola 156657220 유지
    156633180,  # 19427737: De Zerbi 156633008 유지
    151012948,  # 19433480: Henriksen 151012790 유지
    156628042,  # 19433744: Ilzer 156628016 유지
    152244622,  # 19433851: Pocognoli 152244581 유지
    152016125,  # 19467788: Digard 152016165 유지
    152457530,  # 19433877: Pocognoli 152457226 유지
    156039651,  # 19433931: Fonseca 156039210 유지
    156036319,  # 19467840: Puel 156036230 유지
    156252577,  # 19467860: Fonseca 156252579 유지
    156325635,  # 19467869: Fonseca 156325659 유지
    156660301,  # 19467899: Fonseca 156659510 유지
    156739566,  # 19467911: O'Neil 156738505 유지
    151203723,  # 19424904: Pioli 151202014 유지; 87·89분 차이는 근거 문서에 구분했어요.
    151320115,  # 19424918: Gilardino 151320156 유지
    151669026,  # 19424933: Pioli 151667058 유지
    152196732,  # 19424992: Gasperini 152196789와 별도 퇴장 152196790 유지
    152210030,  # 19424998: Gilardino 152210049 유지
    152498988,  # 19425073: Vanoli 152498694와 별도 퇴장 152498148 유지
    152542973,  # 19425086: Grosso 152542957 유지
    152582737,  # 19425096: Gilardino 152582172 유지
    152713810,  # 19425113: Baroni 152713792 유지
    152713912,  # 19425113: Vanoli 152713794 유지
    156085503,  # 19425143: Conte 156085150 유지
    156099959,  # 19425148: Grosso 156099497 유지
    152202386,  # 19439374: Simeone 152202600 유지
    152185997,  # 19439379: Marcelino 152185989 유지
    152302730,  # 19439395: Pellegrini 152302685 유지
    152318849,  # 19439396: Alonso 152318748 유지
    152293851,  # 19439399: Bordalás 152293475 유지
    152351467,  # 19439400: Simeone 152351418 유지
    152411185,  # 19439412: Simeone 152409988 유지
    152546265,  # 19439447: Marcelino 152545970 유지
    152584202,  # 19439454: Sarabia 152583320 유지
    152723641,  # 19439474: Bordalás 152723603 유지
    156037875,  # 19439493: Arrasate 156037869 유지
    156083139,  # 19439500: Marcelino 156082192 유지
    156176340,  # 19439514: Bordalás 156176329 유지
    156226941,  # 19439520: Bordalás 156226729 유지
    156208564,  # 19439522: Marcelino 156208996 유지
    156451182,  # 19439540: Simeone 156451203 유지
    156872728,  # 19439593: Sarabia 156872699 유지
    # 같은 표본의 Sammarco·Palladino는 DB에 선수 이력이 있어 FK 오류가 나지 않았어요.
    # 현장 기록에도 감독 경고는 각각 한 건이라 선수 FK의 중복을 함께 제외해요.
    # https://www.ansa.it/sito/photostory/calcio/2026/02/28/calcio-verona-napoli-1-2_32ff6439-004c-422b-8431-1ef07c3ad781.html
    156085457,  # 19425143: Sammarco 156085300 유지
    # https://www.bergamoesport.it/gli-eroi-anti-dortmund-crollano-sotto-il-muro-neroverde-in-11-contro-10-musah-tardivo/
    156101714,  # 19425148: Palladino 156109156 유지
    # Le Havre–Brest(19715618)의 Digard 경고는 38분 한 건이에요.
    # 10분 선수 경고는 해설 11198129의 Mpasi예요. 감독 ID가 있는 157795532를 남겨요.
    # https://www.laliga.com/en-AR/match/temporada-2026-2027-ligue-1-le-havre-brest-3
    157795519,
    # Espanyol–Sevilla(19732708): Luis García는 Sevilla 감독이며 경고는 57분이에요.
    # Espanyol·14분으로 잘못 복제된 행만 제외하고 157821713·Cala의 경고는 남겨요.
    # https://www.laliga.com/en-US/match/temporada-2026-2027-laliga-ea-sports-rcd-espanyol-de-barcelona-sevilla-fc-4
    157821701,
}


class SportmonksClient:
    """
    Sportmonks Football API v3 클라이언트예요.

    확인한 응답 규칙은 다음과 같아요.
      - 단건 엔드포인트: 최상위 {"data": dict, ...}
      - 목록 엔드포인트: 최상위 {"data": list, ...}
      - 페이지가 있는 엔드포인트: 최상위 "pagination.has_more"
    """

    def __init__(
        self,
        api_base: Optional[str] = None,
        token: Optional[str] = None,
        timeout: int = 60,
        request_interval_sec: float = 1.5,
    ):
        self.base = (
            api_base
            or os.getenv("SPORTMONKS_BASE_URL")
            or "https://api.sportmonks.com/v3/football"
        ).rstrip("/")

        self.token = token or os.getenv("SPORTMONKS_API_TOKEN")

        if not self.token:
            raise RuntimeError("SPORTMONKS_API_TOKEN is not set")

        self.timeout = timeout
        self.request_interval_sec = float(
            os.getenv("SPORTMONKS_REQUEST_INTERVAL_SEC", str(request_interval_sec))
        )
        self._last_request_at = 0.0
        self._session = requests.Session()

    def _wait_before_request(self) -> None:
        elapsed = time.monotonic() - self._last_request_at

        if elapsed < self.request_interval_sec:
            time.sleep(self.request_interval_sec - elapsed)

    def _get(
        self,
        path: str,
        params: Optional[Dict] = None,
        base_url: Optional[str] = None,
    ) -> Dict:
        request_base = (base_url or self.base).rstrip("/")
        url = f"{request_base}/{path.lstrip('/')}"
        headers = {
            "Accept": "application/json",
            "Authorization": self.token,
        }

        self._wait_before_request()
        try:
            response = self._session.get(
                url,
                headers=headers,
                params=params or {},
                timeout=self.timeout,
            )
        finally:
            self._last_request_at = time.monotonic()

        response.raise_for_status()
        return response.json()

    # ------------------------------------------------------------------
    # 페이지가 있는 목록
    # ------------------------------------------------------------------

    def _iter_paginated_data(
        self,
        path: str,
        *,
        params: Optional[Dict] = None,
        base_url: Optional[str] = None,
    ):
        request_params = dict(params or {})

        while True:
            response = self._get(
                path,
                params=request_params,
                base_url=base_url,
            )

            # 코파 델 레이 26/27처럼 조회 결과가 비면 pagination도 제공되지 않아요.
            if not response["data"]:
                return

            yield from response["data"]
            pagination = response["pagination"]

            if not pagination["has_more"]:
                break

            # 실제 다중 페이지 응답의 next_cursor URL에 다음 요청 매개변수가 들어 있어요.
            request_params = dict(
                parse_qsl(urlparse(pagination["next_cursor"]).query)
            )

    # ------------------------------------------------------------------
    # Sportmonks Core 국가 정보
    # ------------------------------------------------------------------

    def iter_countries(self) -> Iterable[Dict]:
        # 축구 리소스는 /v3/football을 쓰고, 국가 목록은 같은 Sportmonks API의
        # /v3/core에서 제공해요.
        core_base = f"{self.base.removesuffix('/football')}/core"
        return self._iter_paginated_data(
            "countries",
            params={"per_page": 100},
            base_url=core_base,
        )

    # ------------------------------------------------------------------
    # Sportmonks 대회와 시즌
    # ------------------------------------------------------------------

    # Sportmonks는 대회 리소스를 "leagues", 식별자를 league_id라고 불러요.
    # 여기서는 공급자 이름을 유지하고, 로더와 DB 경계에서
    # competitions.competition_id로 연결해요.

    def get_league_with_seasons(self, league_id: int) -> Dict:
        response = self._get(
            f"leagues/{league_id}",
            params={"include": "seasons"},
        )
        return response["data"]

    # ------------------------------------------------------------------
    # 팀
    # ------------------------------------------------------------------

    def iter_teams_by_season(self, season_id: int) -> Iterable[Dict]:
        response = self._get(f"teams/seasons/{season_id}")
        yield from response["data"]

    def get_team_with_sidelined(self, team_id: int) -> Dict:
        """
        확인한 include 값이에요.
          sidelined.player;sidelined.type
        """
        response = self._get(
            f"teams/{team_id}",
            params={"include": "sidelined.player;sidelined.type"},
        )
        return response["data"]

    def get_team_squad(self, team_id: int) -> List[Dict]:
        response = self._get(
            f"squads/teams/{team_id}",
            params={
                "include": "player;position;detailedPosition;transfer",
            },
        )

        return response["data"]

    def get_team_season_squad(self, team_id: int, season_id: int) -> List[Dict]:
        # Sportmonks가 시즌 스쿼드라고 부르는 데이터예요. 1Touch에서는 완료된 시즌의
        # 명단을 재구성하는 바탕으로만 써요. 공식 시즌 종료 등록 명단으로 보지 않아요.
        response = self._get(
            f"squads/seasons/{season_id}/teams/{team_id}",
            params={"include": "player"},
        )

        return response["data"]

    # ------------------------------------------------------------------
    # 선수
    # ------------------------------------------------------------------

    def get_player_or_none(self, player_id: int) -> Optional[Dict]:
        response = self._get(f"players/{player_id}")
        # 시즌 스쿼드에는 남아 있지만 선수 단건 응답에는 data가 없는 ID가 있어요.
        # 이 경우에만 검증된 스쿼드 내장 프로필을 대신 쓰도록 None으로 구분해요.
        if "data" not in response:
            return None
        return response["data"]

    def get_player_with_trophies(self, player_id: int) -> Dict:
        response = self._get(
            f"players/{player_id}",
            params={
                "include": (
                    "trophies.team;trophies.league;"
                    "trophies.season;trophies.trophy"
                ),
            },
        )
        return response["data"]

    # ------------------------------------------------------------------
    # 경기
    # ------------------------------------------------------------------

    def iter_fixtures_by_season(
        self,
        season_id: int,
        per_page: int = 100,
        include: str = "participants;state;scores;round;stage;group",
    ) -> Iterable[Dict]:
        return self._iter_paginated_data(
            "fixtures",
            params={
                "filters": f"fixtureSeasons:{season_id}",
                "per_page": per_page,
                "include": include,
            },
        )

    def iter_team_fixtures_between_dates(
        self,
        team_id: int,
        start_date: date,
        end_date: date,
        include: str,
    ) -> Iterable[Dict]:
        return self._iter_paginated_data(
            (
                f"fixtures/between/{start_date.isoformat()}/"
                f"{end_date.isoformat()}/{team_id}"
            ),
            params={
                "include": include,
                "per_page": 100,
            },
        )

    def get_fixture_with_statistics(self, fixture_id: int) -> Dict:
        response = self._get(
            f"fixtures/{fixture_id}",
            params={"include": "participants;statistics.type"},
        )
        return response["data"]

    def get_fixture_details(self, fixture_id: int) -> Dict:
        response = self._get(
            f"fixtures/{fixture_id}",
            params={
                "include": (
                    "events.type;statistics.type;lineups.details;"
                    "lineups.player;formations;coaches;pressure"
                )
            },
        )
        fixture = response["data"]
        fixture["events"] = [
            event for event in fixture["events"] if event["id"] not in SPORTMONKS_DUPLICATE_EVENT_IDS
        ]
        for event in fixture["events"]:
            correction = SPORTMONKS_EVENT_OVERRIDES.get(event["id"])
            if correction is not None:
                event.update(correction)
            player_id = SPORTMONKS_EVENT_PLAYER_PROFILE_IDS.get(event["id"])
            if player_id is not None:
                # 이벤트 선수 전체를 자동 추가하면 잘못 연결된 선수·감독까지 저장돼요.
                event["verified_player_profile"] = self._get(f"players/{player_id}")["data"]
        return self._correct_lineup_players(fixture)

    def _correct_lineup_players(self, fixture: Dict) -> Dict:
        for lineup in fixture["lineups"]:
            profile = SPORTMONKS_LINEUP_PLAYER_PROFILE_OVERRIDES.get(lineup["id"])
            if profile is not None:
                player_id = profile["id"]
            else:
                player_id = SPORTMONKS_LINEUP_PLAYER_ID_OVERRIDES.get(lineup["id"])
                if player_id is None:
                    continue
                profile = self._get(f"players/{player_id}")["data"]
            lineup["player_id"] = player_id
            # ID만 바꾸면 신규 선수에게 원래 연결된 다른 사람의 프로필을 저장하게 돼요.
            lineup["player"] = dict(profile)
        return fixture

    # ------------------------------------------------------------------
    # 순위
    # ------------------------------------------------------------------

    def get_standings_for_season(self, season_id: int) -> List[Dict]:
        """시즌의 공식 순위를 가져와요."""
        response = self._get(
            f"standings/seasons/{season_id}",
            params={"include": "details.type"},
        )
        return response["data"]

    def get_standings_for_round(self, round_id: int) -> List[Dict]:
        """특정 라운드의 공식 순위를 가져와 직전 라운드와 순위 변화를 계산해요."""
        response = self._get(f"standings/rounds/{round_id}")
        return response["data"]

    def get_rounds_for_season(self, season_id: int) -> List[Dict]:
        """시즌의 모든 라운드를 가져와요. round의 name은 경기일 번호 문자열이에요."""
        response = self._get(f"rounds/seasons/{season_id}")
        return response["data"]

    # ------------------------------------------------------------------
    # 이적
    # ------------------------------------------------------------------

    def iter_transfers_by_team(
        self,
        team_id: int,
        per_page: int = 50,
    ) -> Iterable[Dict]:
        return self._iter_paginated_data(
            f"transfers/teams/{team_id}",
            params={
                "per_page": per_page,
                "include": "player;fromTeam;toTeam;type",
            },
        )

    def iter_transfers_between_dates(
        self,
        start_date: date,
        end_date: date,
    ):
        return self._iter_paginated_data(
            f"transfers/between/{start_date.isoformat()}/{end_date.isoformat()}",
            params={
                "include": "player;fromTeam;toTeam;type",
                "per_page": 50,
                "order": "asc",
            },
        )

    # ------------------------------------------------------------------
    # 상태
    # ------------------------------------------------------------------

    def iter_states(self) -> Iterable[Dict]:
        return self._iter_paginated_data(
            "states",
            params={},
        )
