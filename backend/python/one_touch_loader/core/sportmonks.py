from __future__ import annotations

import os
import time
from datetime import date
from typing import Dict, Iterable, List, Optional
from urllib.parse import parse_qsl, urlparse

import requests
from dotenv import load_dotenv

from .transfer_source_rules import DUPLICATE_TRANSFER_IDS as SPORTMONKS_DUPLICATE_TRANSFER_IDS
from .transfer_source_rules import TRANSFER_DATE_OVERRIDES


load_dotenv()


# 공식 명단·다른 경기 응답·선수 단건 프로필로 확인한 라인업 ID만 보정해요.
SPORTMONKS_LINEUP_PLAYER_ID_OVERRIDES = {

    # 2022-existing 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022-existing_completion 자료에 있어요.
    6692218096: 37598758,
    6260860126: 37590595,
    6692195737: 37490756,

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    884743352: 91467,

    # 2025 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025_completion 자료에 있어요.
    14670350584: 179561,
    14670618905: 37649393,
    14670618907: 37675230,
    14671668526: 189268,
    14671668527: 37766148,
    14671668544: 37702358,
    14671656011: 259968,
    14671656023: 37296881,
    14671656414: 37765709,

    # 2024 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2024_completion 자료에 있어요.
    10957342948: 37743072,
    13894047243: 32002912,
    13894047259: 37594407,
    13894047257: 122938,
    13894047253: 382366,
    13894047238: 37728025,
    14174750794: 380097,
    14174750792: 325895,
    14174750787: 35709115,
    14148115875: 33587403,
    14148115873: 33186396,
    14148119059: 37544918,
    14148119067: 37297406,
    14148119060: 37588013,
    14148115877: 33213251,
    14148115881: 37316697,
    14148119063: 37770864,
    14175574389: 35709119,
    14175574292: 37669685,

    # 2023 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2023_completion 자료에 있어요.
    5317543729: 37728174,
    5317543739: 37728176,
    5736304269: 380710,
    5732404495: 211387,

    # 2022-barbadas 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022-barbadas_completion 자료에 있어요.
    6657953537: 26581922,
    6657951925: 27048646,

    # 2022 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022_completion 자료에 있어요.
    6259787052: 37671245,
    6259786803: 37703328,
    867462095: 33576963,
    6259780207: 37671254,
    6259780190: 37266518,
    6259780205: 37671259,
    6259778404: 37672896,
    6259778507: 37430535,
    6259776760: 37614327,
    875437532: 37262631,
    6259776757: 448861,
    6259776782: 37297088,
    867833361: 32795424,
    996187170: 37297088,
    6656844548: 27048645,
    6259773988: 3877045,
    993425863: 32810181,
    6259739616: 185582,
    6259738017: 37584398,
    993409344: 379899,
    993409341: 380906,
    993409362: 37263698,
    992950100: 21772820,
    6259737885: 188920,
    6259749338: 380405,
    990822056: 381026,
    6259749091: 37316743,
    990511997: 27440862,
    6656825461: 35682993,
    6656825463: 37566135,
    995619925: 25922093,
    6259742273: 447277,
    6259653538: 25922093,
    6259653347: 37304143,
    6259653895: 447277,
    6259653892: 36083679,
    6259653894: 37620542,
    6259653897: 37545309,
    6259653883: 37543892,
    1031433425: 37357549,
    6652473381: 37615413,
    1032822500: 30850889,

    # 2021 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2021_completion 자료에 있어요.
    1054366: 37608671,
    1129823: 185827,
    1183422: 14955,
    1368906: 192243,

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    7790809: 383480,
    7790797: 33608622,
    7790520: 26304346,
    7791168: 37325865,
    6265060853: 1500843,
    6265062320: 26312527,

    # 2020 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2020_completion 자료에 있어요.
    9451635: 129104,
    9547380: 28551735,

    # 2018 컵 경기표와 생일을 대조한 선수예요. 동명이인과 중복 슬롯을 구분해요.
    6402566881: 128951,
    6402568739: 128294,
    6402566897: 132368,
    6170002: 8761,
    6209470: 2882,
    # Floriana의 실제 3번 James와 생일·이적 경력을 대조했어요. 상세의 선수 ID는 이미 James예요.
    # 근거: 20260921-2017-floriana-verified-repairs.json. 다른 Darrell 프로필만 교체하고 90분·상세는 유지해요.
    4251467: 1444085,
    # 반환 경기표로 선발·교체·미출전 후보와 생일을 확인했어요. 빈 분·통계는 그대로 둬요.
    # 근거: 20260921-2025-tre-fiori-return-verified-repairs.json. Manfroni 자책골은 원래 행이 맞아요.
    14670316085: 5640808,
    14670316269: 37773408,
    14670316267: 22889283,
    14670316268: 37595507,
    # Sant Andreu–Celta의 실제 명단·교체와 전체 이름·생일을 확인한 세 선수예요.
    # 근거: 20260921-2025-sant-andreu-verified-repairs.json. 원래 분·평점·상세는 유지해요.
    14671673456: 37655317,
    14671673464: 37640778,
    14671673466: 448466,
    # 실제 컵 16번 Ticiano·36번 Nico의 출전과 전체 이름·생일을 대조했어요. 원래 상세는 유지해요.
    # 근거: 20260921-2025-quintanar-verified-repairs.json. 시즌 명단에서 빠진 Nico는 구단·LaLiga로 확인했어요.
    14671668439: 37761933,
    14671668424: 37786133,
    # Navalcarnero의 실제 11·21번, 교체·득점·도움과 전체 이름·생일을 대조했어요. 기존 상세는 유지해요.
    # 근거: 20260921-2025-navalcarnero-verified-repairs.json. 시즌 명단의 다른 21번 Maroto는 쓰지 않아요.
    14671658430: 37550527,
    14671658425: 37717976,
    # 실제 컵 명단·Cano 경고·Tapiador 자책골과 정확한 생일을 대조했어요. 기존 분·상세는 유지해요.
    # Cano는 시즌 명단의 다른 5번 Murillo와 달라요. 근거: 20260921-2025-cano-tapiador-verified-repairs.json.
    14671673528: 37297130,
    14671656186: 37718920,
    # 실제 FA컵 42번·82분 교체·득점과 구단·Opta 생일로 Birch를 확인했어요. 원래 8분·상세는 유지해요.
    # 근거: 20260921-2025-birch-verified-repairs.json.
    14671853180: 37772590,
    # Tre Fiori 첫 경기의 실제 선발·교체와 협회·Opta 생일을 대조했어요. 기존 상세는 유지해요.
    # 근거: 20260921-2025-tre-fiori-first-verified-repairs.json. 시즌 명단에서 빠진 Manfroni도 협회가 확인해요.
    14670288809: 37595507,
    14670288810: 37773408,
    14670288745: 5640808,
    # Egnatia의 27번 Jefferson은 UEFA 생일·전체 이름·네 경기 교체를 대조했어요. 빈 상세는 유지해요.
    # 근거: 20260921-2025-egnatia-jefferson-verified-repairs.json.
    14670350172: 37630540,
    14670390902: 37630540,
    14670436561: 37630540,
    14670496246: 37630540,
    # Kolgeci의 UEFA 생일·두 경기 출전·23번 명단을 대조했어요. 미제공 분·통계는 만들지 않아요.
    # 근거: 20260921-2025-kolgeci-verified-repairs.json.
    14670343768: 37761577,
    14670390670: 37761577,
    # 실제 후보 17번 Warlow는 생일·시즌 명단·벤치 퇴장을 대조했어요. 출전 오기는 아래에서 비워요.
    # 근거: 20260921-2025-warlow-verified-repairs.json.
    14670316645: 17576,
    # Sarajevo의 Mlinarić·TNS의 Owen은 협회·구단 경기표와 생일·경력을 대조했어요.
    # 근거: 20260921-2025-sarajevo-owen-verified-repairs.json. 기존 분·평점·상세는 유지해요.
    14670350259: 37287261,
    14670381003: 37767760,
    # Conquense 실제 명단·시즌 소속·독립 전체 이름과 경력으로 확인한 아홉 슬롯이에요.
    # 근거: 20260921-2024-conquense-verified-repairs.json. 미제공 생일·기존 상세값은 유지해요.
    14192680462: 381170,
    14192680466: 383989,
    14192680463: 35709091,
    14192680478: 37263412,
    14192680454: 37550717,
    14192680455: 37674232,
    14192680448: 37724059,
    14192680453: 37784165,
    14192680461: 37717981,
    # Orihuela 실제 명단·시즌 소속·단건과 독립 프로필을 대조한 다섯 슬롯만 연결해요.
    # 근거: 20260921-2024-orihuela-verified-repairs.json. Morales의 미제공 생일은 유지해요.
    14190448228: 382306,
    14190448167: 37412546,
    14190448216: 37543800,
    14190448220: 37619809,
    14190448224: 31625657,
    # Sant Andreu 실제 명단·시즌 소속·전체 이름과 생일로 확인한 빈 슬롯만 연결해요.
    # 근거: 20260921-2024-sant-andreu-verified-repairs.json
    14171382255: 538504,
    14171382236: 12165041,
    14171382230: 31226261,
    14171382231: 37289764,
    # Olot 실제 3·16·19번과 구단 공식 전체 이름·생일을 대조한 빈 슬롯만 연결해요.
    # 근거: 20260921-2024-olot-verified-repairs.json. Gonpi는 형제 Álex와 다른 선수예요.
    14193305770: 525680,
    14193305785: 30831801,
    14193305771: 37592561,
    # Ceuta 실제 18번 Sofiane의 구단 공식 생일과 일치하는 빈 슬롯만 연결해요.
    14190422482: 24073451,
    # 실제 컵 명단·교체·생일로 확인했어요. 시즌 응답의 동명이인·같은 등번호는 쓰지 않아요.
    # 근거: 20260921-2024-swansea-edu-verified-repairs.json
    14652111576: 37583461,  # Swansea 47번 Abdulai: 잘못 연결된 Abdullah만 교정해요.
    14652111563: 9599,  # Swansea 11번 Ginnelly: 기존 11분·6.24점을 유지해요.
    14602816465: 382722,  # Pontevedra 미출전 후보 Edu Sousa: 75분 경고는 그대로 유지해요.
    # Cacereño 실제 8번 Deco의 구단 공식 이름·생일과 일치하는 기존 빈 슬롯이에요.
    14190345177: 383386,
    # 실제 컵 명단·시즌 소속·단건 프로필을 대조한 연결이에요. 다른 시즌의 같은 등번호는 쓰지 않아요.
    # 근거: 20260921-2024-logrones-europa-verified-repairs.json
    14175371073: 445782,
    14175371092: 37263420,
    14175371072: 30467859,
    14175371066: 37544118,
    14175371083: 37688121,
    14175371078: 26523846,
    14152461588: 30467875,
    14152461575: 447300,
    14152461587: 37304063,
    14152461598: 37686001,
    # Salamanca 실제 20·21번과 구단 발표 생일을 대조했어요. 시즌의 다른 20번은 쓰지 않아요.
    # 근거: 20260920-2024-salamanca-verified-repairs.json
    14152461802: 383699,   # Caramelo: 선발 57분, 1995-02-21
    14152461788: 10647528,  # Óscar Lorenzo: 교체 14분, 2000-03-28
    # 실제 컵 명단·교체·같은 시즌 소속·단건 프로필로 확인한 빈 슬롯만 연결해요.
    # 근거: 20260920-2024-cup-two-verified-repairs.json
    13407611945: 37704305,  # Poblense 27번 Ayoub, 기존 17분·7.02점 유지
    13436288858: 37262667,  # Extremadura 3번 Alberto Caro, 기존 23분 유지
    13436288887: 37262730,  # Extremadura 20번 Tala, 기존 67분 유지
    # 실제 교체·같은 시즌 등번호·단건 프로필이 일치하는 기존 두 후보 슬롯만 연결해요.
    # Jagiellonia의 다른 빈 행에는 상대 팀 명단이 섞여 있어 일괄 연결하지 않아요.
    11166901911: 37460555,  # Panevėžys 1차전: 77번 Łaski, 기존 5분 유지
    11327340169: 37629806,  # Panevėžys 2차전: 36번 Lewicki, 기존 18분 유지
    # 실제 교체 명단·같은 시즌 등번호·단건 프로필로 확인한 빈 연결만 보충해요.
    # Pais: https://chernomorepfc.bg/52663-2/ (2000-05-30, 5번)
    11196959425: 37308565,
    # Bandeira: https://fckryvbas.com/post/viktoriya-plzen-krivbas-1-0 (25번)
    11637798320: 6974918,
    # Mustafin: https://www.skysports.com/football/pafos-vs-astana/teams/521939 (96번)
    13619614185: 37659450,
    # 세 컵 경기의 실제 등번호·교체 기록·같은 시즌 소속·단건 프로필을 대조한 빈 연결이에요.
    # Manises–Getafe: https://www.skysports.com/football/manises-vs-getafe/teams/522822
    14001590773: 3876895,
    14001590783: 31648559,
    14001590785: 31648625,
    14001590768: 37786365,
    14001590767: 37786370,
    14001590781: 37786362,
    14001590774: 31625697,
    14001590776: 37297119,
    14001590764: 380522,
    14001590761: 37713992,
    14001590777: 31648563,
    14001590760: 37786368,
    # Chiclana–Osasuna: Popi는 2001-07-10생 Manzorro이고 실제 23번이에요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-chiclana-cf-ca-osasuna-2
    13586488680: 380432,
    13586488689: 9308210,
    13586488674: 22859313,
    13586488682: 37586257,
    13586488696: 37728288,
    13586488677: 37788449,
    13586488679: 37549740,
    # Parla–Valencia: Javito·More의 별칭도 생일·소속·실제 경기 기록으로 확인했어요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-cp-parla-escuela-valencia-cf-2
    14001303483: 445349,
    14001303485: 32810211,
    14001303494: 32810345,
    14001303498: 37262642,
    14001303487: 37543063,
    14001303496: 37565149,
    14001303475: 37786924,
    14001303497: 37786927,
    14001303493: 37786928,
    14001303489: 37263972,
    14001303500: 37786931,
    # Ejea의 17번 Rodri·23번 Santana는 별개 선수예요. 경기 명단·시즌 소속·생일을 대조했어요.
    # https://www.espn.com.gt/football/lineups?gameId=723891
    14176285946: 37263060,
    14176285941: 3510306,
    # 같은 경기 2·21·22번의 교체 기록과 시즌 명단도 대조해 빈 선수 연결만 채워요.
    14176285953: 27440263,
    14176285937: 37296890,
    14176285951: 37262581,
    # Velež 두 경기의 Mlinarić·Lohan은 협회 생일·구단 영입·실제 명단을 대조했어요.
    # https://semafor.hns.family/igraci/182422/mihael-mlinaric/
    # https://fkvelez.ba/elzio-lohan-novi-igrac-fk-velez/
    10951508407: 37287261,
    11067586803: 37287261,
    10951567640: 37457529,
    11067586823: 37457529,
    # Osasuna전 27번은 구단이 생일을 확인한 Alassan이에요. 불완전한 다른 프로필만 교정해요.
    # https://www.clubdeportivotenerife.es/noticias/alassan-cedido-a-la-union-deportiva-melilla
    14613111437: 37602913,
    # Doncaster의 두 컵 경기 16번은 Nixon이에요. 경기별 교체 기록·단건 소속을 대조했어요.
    # https://www.skysports.com/football/everton-vs-doncaster-rovers/teams/521190
    # https://preprod.cpfc.co.uk/news/match-reports/live-blog-doncaster-rovers-v-crystal-palace-report-february-2025/
    11934480093: 37259186,
    14668918453: 37259186,
    # Víkingur Reykjavík vs The New Saints (18601727): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/vikingur-reykjavik-vs-the-new-saints-fc/teams/474080
    10494668: 37640160,
    6671246635: 37640348,
    6671246627: 37625295,
    # The New Saints vs Víkingur Reykjavík (18601728): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/the-new-saints-fc-vs-vikingur-reykjavik/teams/474081
    10515769: 37640160,
    6671209172: 37640348,
    6671209080: 37625295,
    # KF Ballkani vs La Fiorita (18601718): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.livesoccertv.com/match/la-fiorita-vs-ballkani/34oayr
    6671225507: 37615918,
    6671231843: 338755,
    # Inter Club d'Escaldes vs CFR Cluj (18601726): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/inter-club-descaldes-vs-cfr-cluj-napoca/teams/470944
    10517984: 379819,
    10518089: 37528680,
    6260413661: 188449,
    6260413124: 448451,
    # Laçi vs Petrocub (18534874): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/laci-vs-petrocub-hincesti/teams/474111
    10522078: 1481036,
    6691075816: 37559007,
    # Čukarički vs Racing (18534876): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://donfutbolisto.com/en/game/cukaricki-racing-union-conference-league-28-07-2022/
    6260817232: 37623061,
    10522084: 64248,
    6260816878: 37575599,
    6260817214: 65173,
    6260817234: 37265593,
    6260817051: 5283565,
    6260816964: 37644613,
    # Várda SE vs Molde (18601686): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/kisvarda-vs-molde/teams/476430
    6671276205: 37644152,
    53020118: 113589,
    # F91 Dudelange vs Lech Poznań (18634398): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/f91-dudelange-vs-lech-poznan/teams/476865
    196366601: 140713,
    6665561918: 37577581,
    6665562506: 141089,
    # Sivasspor vs Slavia Praha (18674566): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/sivasspor-vs-slavia-prague/teams/477554
    353358802: 37643750,
    6661508862: 37577340,
    6661502043: 37643754,
    # Slavia Praha vs CFR Cluj (18674570): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://www.skysports.com/football/slavia-prague-vs-cfr-cluj-napoca/teams/477587
    591945206: 37643750,
    6661476582: 37577340,
    6661477465: 37643754,
    # Hapoel Be'er Sheva vs Lech Poznań (18674524): 이 경기 명단과 선수 단건 프로필을 대조했어요.
    # https://football-italia.net/match/uefa-conference-league-2022-23-hapoel-bs-vs-lech-poznan/
    653673135: 37666322,
    6661527741: 37666321,
    # Larne vs St Josephs FC(18533261): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://www.rte.ie/sport/results/soccer/europa-conference-league/17778/report-3899220/
    10465179: 449605,
    6692206577: 37640346,
    6692206574: 36083593,
    6692208387: 37640345,
    # Breidablik vs UE Santa Coloma(18533263): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://www.laliga.com/en-GB/match/temporada-2022-2023-europa-conference-league-breidablik-ue-santa-coloma-2
    10465437: 30831795,
    6260863316: 336974,
    6260862840: 37262563,
    6260862852: 37342757,
    6260862842: 37406994,
    6260862441: 12058756,
    6260863322: 37549505,
    6260862838: 30491819,
    6260862609: 162167,
    # Crusaders vs Magpies(18533287): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://donfutbolisto.com/en/game/crusaders-magpies-conference-league-14-07-2022/
    6692182002: 379826,
    # St Josephs FC vs Slavia Praha(18534849): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://www.skysports.com/football/st-josephs-vs-slavia-prague/teams/464584
    6691093412: 449605,
    6691093123: 37640346,
    6691095216: 36083593,
    6691095214: 37640345,
    10493249: 383558,
    # B36 vs Tre Fiori(18534865): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://www.fsgc.sm/assets/documents/566.pdf
    # 다음 라운드의 9·25번은 Mani·Landi예요. 앞선 Fola전의 같은 등번호와 달라요.
    10493371: 37644176,
    6691079760: 37619775,
    # Petrocub vs Laçi(18534873): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://www.skysports.com/football/petrocub-hincesti-vs-laci/teams/474105
    10493458: 1481036,
    6691079132: 37559007,
    # Racing vs Čukarički(18534875): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://www.skysports.com/football/racing-luxembourg-vs-cukaricki-belgrade/teams/464574
    10494002: 37623061,
    10493942: 64248,
    6260824785: 37575599,
    6260824719: 65173,
    6260824783: 37644613,
    6260822967: 37644614,
    6260822232: 5283565,
    6260821765: 37265593,
    # La Fiorita vs KF Ballkani(18601717): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://sport.sky.de/fussball/la-fiorita-vs-ballkani/aufstellung/470940
    6671252280: 37634520,
    6671250585: 37615918,
    6671251267: 338755,
    # CFR Cluj vs Inter Club d'Escaldes(18601725): 경기 명단·상세/교체 ID·단건 프로필로 확인한 슬롯이에요.
    # https://sport.sky.de/fussball/cluj-vs-inter-club-d-escaldes/aufstellung/470942
    10493694: 379819,
    6260401337: 37528680,
    6260401714: 188449,
    6260401716: 448451,
    # St Josephs–Larne(18533260)의 선발 여섯 명에 Baxtiyar의 ID가 반복됐어요.
    # 등번호·교체 이벤트·단건 프로필을 대조해 선수와 기존 출전 시간 상세를 바로잡아요.
    # https://www.laliga.com/en-GB/match/temporada-2022-2023-europa-conference-league-st-josephs-larne-1
    10437871: 449605,
    6260859479: 36083593,
    6260859481: 380095,
    6260858781: 37565521,
    6260858777: 396038,
    6260858779: 379717,
    # Llapi–Budućnost 두 경기의 9·12·14번은 Firmino·Bujupi·Aulon Shabani예요.
    # 9번은 상세 ID와 70/75분 교체 기록이 일치해요. 다른 후보의 빈 상세는 보존해요.
    # https://www.mackolik.com/mac/buducnost-vs-llapi/8t8g8uoibiiaimedge3uh8ob8
    # https://www.fotmob.com/en-GB/matches/buducnost-podgorica-vs-llapi/40l4nalo
    10442022: 37544627,
    6692223307: 37635848,
    6692223310: 37598716,
    10464950: 37544627,
    6692218649: 37635848,
    6692218092: 37598716,
    # Tre Fiori–Fola 두 경기의 아홉 명은 구단의 예선 등록 명단·등번호와 일치해요.
    # 3번 상세 ID, Núñez·Procacci·Ferri의 교체 ID, 나머지 단건 프로필을 대조했어요.
    # https://www.trefiori.sm/il-tre-fiori-e-pronto-per-landata-del-primo-turno-di-conference-league-giovedi-in-casa-dei-lussemburghesi-del-fola-esch/
    # 출전한 후보라도 공급자의 상세가 비어 있으면 통계를 새로 만들지 않아요.
    10441745: 37595027,
    6390378188: 396447,
    6390377761: 37640755,
    6390377751: 338614,
    6390378186: 37640756,
    6390377763: 367934,
    6390377443: 37597684,
    6390378164: 134427,
    6390378182: 37595456,
    6260851287: 37595027,
    6260851640: 396447,
    6260853112: 37640755,
    6260852289: 338614,
    6260852311: 37640756,
    6260853114: 367934,
    6260852324: 37597684,
    6260853073: 134427,
    6260853120: 37595456,
    # Akademija–Lechia(18533235)의 후보 2·6·17·92번을 경기 명단·1차전 ID와 대조했어요.
    # https://www.skysports.com/football/akademija-pandev-vs-lechia-gdansk/teams/464201
    6692240787: 37632153,
    6692239602: 24469128,
    6692240785: 37586104,
    6692240791: 37530339,
    # Escaldes–Gzira(18533255)의 3·11·21·27번은 상세 ID·교체 기록과 일치해요.
    # 21번 Morales의 73분은 보정하되, 11·27번의 빈 상세는 그대로 둬요.
    # https://www.skysports.com/football/atletic-escaldes-vs-gzira-united/teams/464203
    10464655: 18907213,
    6260860132: 33213291,
    6260860120: 12299021,
    6260860137: 37549311,
    # Europa–Víkingur(18533267)는 후보 다섯 명의 ID만 복원해요. 선발 20번 Heredia는 맞아요.
    # 1차전 ID·2차전 명단·단건 프로필을 대조해 정상 선수까지 바꾸지 않아요.
    # https://www.skysports.com/football/europa-fc-vs-vikingur/teams/464211
    6692195733: 37640490,
    6692194396: 35709128,
    6692194389: 19026,
    6692195735: 539912,
    6692195721: 380776,
    # Tre Penne–Tuzla(18533274)의 후보 세 명은 2차전 ID·경기 명단으로 확인했어요.
    # https://www.skysports.com/football/tre-penne-vs-tuzla-city/teams/464199
    10442144: 37633098,
    6692211184: 37633100,
    6692212353: 37633376,
    # Shkupi–Shamrock(18595876)의 31·47·70·99번에 Tom Booth가 반복됐어요.
    # 경기 명단·31번 상세 ID·선수 단건 프로필을 대조한 네 후보만 복원해요.
    # https://www.skysports.com/football/shkupi-vs-shamrock-rovers/teams/476254
    41945831: 37575634,
    6672115341: 37599568,
    6672112605: 37629260,
    6672113368: 37575633,
    # Dudelange–Malmö(18595874)의 선발 6번은 Vova예요. 원본의 90분은 보존해요.
    # 77번 Mendes는 67분 교체 ID와 일치해요. 비어 있는 출전 시간 상세는 만들지 않아요.
    # https://www.skysports.com/football/f91-dudelange-vs-malmo-ff/teams/476251
    52506219: 140713,
    6672130304: 37577581,
    6672136329: 141089,
    6672136316: 37642778,
    # 22/23 예선의 후보 슬롯에 다른 선수 ID가 반복됐어요. 경기 명단·상세 ID·단건 프로필을 대조했어요.
    # Tirana–Dudelange(18533298): 14번 Ninte의 5분·경고는 그대로 보존해요.
    # https://www.skysports.com/football/kf-tirana-vs-f91-dudelange/teams/464169
    10459964: 37577581,
    10459966: 141089,
    10459967: 37604616,
    # Linfield–TNS(18533310)의 34번 Kirkman과 35번 Lock은 서로 다른 미출전 후보예요.
    # https://www.skysports.com/football/linfield-vs-the-new-saints-fc/teams/464163
    10462078: 37640160,
    6692161298: 37640348,
    # Pyunik–Dudelange(18534381)의 17번 Silva와 22번 Antunes를 복원해요.
    # https://www.rte.ie/sport/results/soccer/champions-league/17697/report-3899827/
    6691369037: 141089,
    6691369147: 37604616,
    # Dudelange–Pyunik(18534382): 6번 Vova는 60분 투입돼요. 원본의 30분을 보존해요.
    # 90분 투입된 14번의 출전 시간 상세는 비어 있어 새 통계를 만들지 않아요.
    # https://www.fotmob.com/en-GB/matches/f91-dudelange-vs-pyunik/zbvfo
    10515848: 140713,
    6691366149: 37577581,
    6691366969: 141089,
    6691366962: 37604616,
    # Shkupi–Dinamo(18534388)의 31번 Meljaki와 99번 Abazi도 미출전 후보예요.
    # https://escored.com/match/shkupi-1927-dinamo-zagreb-2022-07-26/
    10516096: 37575634,
    6691362785: 37575633,
    # Rubin–Raków(18320105)의 후보 19번 Ivan과 선발 20번 Vladislav의 ID가 섞였어요.
    # 협회 명단·연장 교체 이벤트·선수 단건 프로필을 대조한 19번만 복원해요.
    # https://www.laczynaspilka.pl/biblioteka/mecze/rubin-kazan-rakow-czestochowa-01-pd-12082021
    444323: 1490712,
    # Sivasspor–Petrocub(18224982)의 후보 10번은 Bejan이에요. 선발 11번 Sergiu와 ID가 섞였어요.
    # 협회 명단·상세 통계의 ID(146210)·선수 단건 프로필을 대조했어요.
    # https://fmf.md/noutate/3471/europa-conference-league-sivassporpetrocub-10
    10023004: 146210,
    # Fola–Lincoln(18137448)의 후보 22번은 골키퍼 Evan이에요. 15번 Rui와 ID가 섞였어요.
    # 경기 명단·2차전의 22번 ID·협회 생년월일(2003-05-07)·단건 프로필을 대조했어요.
    # https://www.live-result.com/football/matches/match1096115_Fola-Lincoln_Red_Imps-online
    # https://sportspress.lu/wp-content/uploads/2019/10/UEFAU17.pdf
    6750256861: 37265578,
    # Sheriff–Teuta(18137433)의 미출전 후보 7번은 Fabjan, 80분 교체된 22번은 Ledio예요.
    # 통계가 없는 슬롯만 Fabjan으로 복원하고, Ledio의 10분은 원래 슬롯에 보존해요.
    # https://fmf.md/noutate/3395/liga-campionilor-sheriffteuta-10?lang=en
    6750272726: 49591,
    # KuPS–Slovan(17055763)의 Udoh·Saxman은 이름·상세 통계는 있지만 선수 ID가 null이에요.
    # 공식 명단·13/20번·교체와 골 기록·단건 프로필을 대조한 두 슬롯만 복원해요.
    # https://en.skslovan.com/zapasy/gamecenter.php?gameID=3681&type=lineups
    9178166: 151627,
    9178028: 90876,
    # Lincoln–Rangers(17055735)의 후보 14번은 Ryan Kent예요. Defoe의 ID·통계가 복사됐어요.
    # 구단 공식 후보 명단·14번 경기 명단·단건 프로필(1996-11-11)을 대조했어요.
    # https://www.rangers.co.uk/article/rangers-make-six-changes-for-red-imps/1PU8GJqq78yvyDbMUi2qew
    9176738: 3387,
    # Charleroi–Partizan(17221039)의 후보 7번도 Dennis예요. 111분 Asano 교체 ID와 일치해요.
    # https://www.skysports.com/football/charleroi-vs-partizan/teams/434311
    6773992085: 37529303,
    # Zrinjski–Differdange(16905168)의 10번은 Almeida예요. 22번 Buch와 ID가 섞였어요.
    # 명단·84분 교체·상세 통계의 ID(140224)·단건 프로필을 대조했어요.
    # https://www.skysports.com/football/zrinjski-mostar-vs-fc-03-differdange/teams/428212
    8985783: 140224,
    # Partizan–RFS(16905177)의 후보 7번은 Dennis Stojković예요. 선발 골키퍼 88번과 달라요.
    # 90+5분 Asano 교체 이벤트의 ID·단건 프로필(2002-08-03)·경기 명단이 일치해요.
    # https://elpais.com/deportes/resultados/futbol/previa_europa_league/2020_2021/directo/primera_ronda-a-1-321778/alineaciones/
    6785920623: 37529303,
    # Celje–Dundalk(16865255)의 6번은 86분 교체 투입된 Nino Pungaršek이에요.
    # 협회 기록·교체 이벤트·4분 출전 상세·단건 프로필의 ID(183562)가 같아요.
    # https://www.nzs.si/podrocja/novinarji/novice/celjani-do-drugega-kroga-kvalifikacij-242031
    8959747: 183562,
    # Zeta–Fehérvár 두 경기의 11번은 공격수 Ivan이 아닌 수비수 Đorđije Vukčević예요.
    # 구단 공식 명단·2차전 경고/퇴장 ID(147611)·선수 단건 프로필을 대조했어요.
    # https://vidi.hu/en/match-centre/videoton-fc-i/2019-2020/196-2019-07-11-fk-zeta-golubovci-mol-fehervar-fc/line-up
    6265471797: 147611,
    6265467104: 147611,
    # Trakai–KÍ(11896778)의 선발 1번은 Kristian, 후보 16번은 Meinhardt Joensen이에요.
    # 경기 명단·상세 통계의 선수 ID·단건 프로필을 대조한 선발 슬롯만 바로잡아요.
    # https://www.skysports.com/football/trakai-vs-ki-klaksvik/teams/409141
    7258545: 85663,
    # Spartak Trnava–Fenerbahçe(10449714)의 63번은 Deniz Yılmaz예요.
    # UEFA 명단·82분 교체 이벤트·상세 통계의 선수 ID·단건 프로필을 대조했어요.
    # https://www.uefa.com/uefaeuropaleague/match/2025275--spartak-trnava-vs-fenerbahce/lineups/
    5999443: 27440170,
    # Hibernian–Gent의 47번은 José Mendieta가 아닌 Josué Vergara예요.
    # UEFA 생일(2007-07-25)·현재 소속·구단의 선발 명단과 39분 골을 대조했어요.
    # https://www.uefa.com/uefaconferenceleague/clubs/players/250222166--josue-vergara/
    14674479239: 37765373,
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
    # Ballkani 원정 후보 5번 Hughes는 구단 경기 기록·현재 소속·단건 프로필을 대조했어요.
    # 선수 ID가 빈 이 슬롯만 복원하고, 67분 교체와 공급자 통계는 그대로 둬요.
    # https://the-nomads.co.uk/matches/first-team/2026-07-16/fc-ballkani/
    14674158335: 38219298,
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

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    884743352: {'id': 91467, 'sport_id': 1, 'country_id': 1233, 'nationality_id': 1233, 'city_id': None, 'position_id': 27, 'detailed_position_id': None, 'type_id': 27, 'common_name': 'R. Amani', 'firstname': 'Rezgar', 'lastname': 'Amani', 'name': 'Rezgar Amani', 'display_name': 'Rezgar Amani', 'image_path': 'https://cdn.sportmonks.com/images/soccer/players/11/91467.png', 'height': None, 'weight': None, 'date_of_birth': '1992-06-01', 'gender': 'male'},

    # 2025 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025_completion 자료에 있어요.
    14670350584: {'id': 179561, 'sport_id': 1, 'country_id': 296, 'nationality_id': 296, 'city_id': None, 'position_id': 26, 'detailed_position_id': None, 'type_id': 26, 'common_name': 'A. Desančić', 'firstname': 'Aleksandar', 'lastname': 'Desančić', 'name': 'Aleksandar Desančić', 'display_name': 'Aleksandar Desančić', 'image_path': 'https://cdn.sportmonks.com/images/soccer/players/9/179561.png', 'height': 177, 'weight': None, 'date_of_birth': '1996-02-20', 'gender': 'male'},
    14670618907: {'id': 37675230, 'sport_id': 1, 'country_id': 462, 'nationality_id': 462, 'city_id': None, 'position_id': 26, 'detailed_position_id': 149, 'type_id': None, 'common_name': 'D. Vost', 'firstname': 'Daniel', 'lastname': 'Vost', 'name': 'Daniel Vost', 'display_name': 'Daniel Vost', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': 186, 'weight': None, 'date_of_birth': '2006-03-17', 'gender': 'male'},
    14671656011: {'id': 259968, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 25, 'detailed_position_id': 148, 'type_id': 26, 'common_name': 'I. Pérez', 'firstname': 'Iván', 'lastname': 'Pérez Dueña', 'name': 'Iván Pérez Dueña', 'display_name': 'Iván Pérez', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': '2003-01-01', 'gender': 'male'},

    # 2024 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2024_completion 자료에 있어요.
    10957342948: {'id': 37743072, 'sport_id': 1, 'country_id': 200, 'nationality_id': None, 'city_id': None, 'position_id': 26, 'detailed_position_id': None, 'type_id': 26, 'common_name': 'P. Diouf Ndiaye Doudou', 'firstname': 'Pape Doudou', 'lastname': 'Diouf Ndiaye', 'name': 'Pape Doudou Diouf Ndiaye', 'display_name': 'Pape Doudou', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': '2003-11-03', 'gender': 'male'},
    13894047243: {'id': 32002912, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 26, 'detailed_position_id': None, 'type_id': 26, 'common_name': 'J. Montoyo Pastor', 'firstname': 'Javier', 'lastname': 'Montoyo Pastor', 'name': 'Javier Montoyo Pastor', 'display_name': 'Monty', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': None, 'gender': 'male'},
    13894047259: {'id': 37594407, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 27, 'detailed_position_id': None, 'type_id': 27, 'common_name': 'A. Sánchez Cartagena', 'firstname': 'Avelino', 'lastname': 'Sánchez Cartagena', 'name': 'Avelino Sánchez Cartagena', 'display_name': 'Avelino Sánchez', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': '2003-09-14', 'gender': 'male'},
    14174750787: {'id': 35709115, 'sport_id': 1, 'country_id': 155, 'nationality_id': 155, 'city_id': None, 'position_id': 26, 'detailed_position_id': 153, 'type_id': 26, 'common_name': 'R. Mezdrea', 'firstname': 'Rares', 'lastname': 'Mezdrea', 'name': 'Rares Mezdrea', 'display_name': 'Rares Mezdrea', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': None, 'gender': 'male'},
    14148115873: {'id': 33186396, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 25, 'detailed_position_id': 148, 'type_id': 25, 'common_name': 'C. Pascual Blanco', 'firstname': 'Carlos', 'lastname': 'Pascual Blasco', 'name': 'Carlos Pascual Blasco', 'display_name': 'Carlos Pascual', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': '1999-11-30', 'gender': 'male'},
    14148115877: {'id': 33213251, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 25, 'detailed_position_id': 155, 'type_id': 26, 'common_name': 'F. Diáz Garrido', 'firstname': 'Fernando', 'lastname': 'Diáz Garrido', 'name': 'Fernando Diáz Garrido', 'display_name': 'Fer Díaz', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': None, 'gender': 'male'},
    14175574292: {'id': 37669685, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 25, 'detailed_position_id': None, 'type_id': None, 'common_name': 'A. Carrasco Navarro', 'firstname': 'Alejandro Jesus', 'lastname': 'Carrasco Navarro', 'name': 'Alejandro Jesus Carrasco Navarro', 'display_name': 'Álex Carrasco', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': None, 'gender': 'male'},

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    7790797: {'id': 33608622, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 26, 'detailed_position_id': None, 'type_id': 26, 'common_name': 'B. Amar Ahmed', 'firstname': 'Bilal', 'lastname': 'Amar Ahmed', 'name': 'Bilal Amar Ahmed', 'display_name': 'Bilal', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': None, 'gender': 'male'},
    6265062320: {'id': 26312527, 'sport_id': 1, 'country_id': 32, 'nationality_id': 32, 'city_id': None, 'position_id': 26, 'detailed_position_id': None, 'type_id': 26, 'common_name': 'J. Fernández Expósito', 'firstname': 'Jon', 'lastname': 'Fernández Expósito', 'name': 'Jon Fernández Expósito', 'display_name': 'Jonfi', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': None, 'weight': None, 'date_of_birth': None, 'gender': 'male'},
    14674190712: {
        "id": 37763035,
        "name": "Arvanit Rexhaj",
        "display_name": "Arvanit Rexhaj",
    },
}

# 실제 교체와 프로필을 확인했지만 라인업 행이 아예 없는 이벤트만 보충해요.
SPORTMONKS_EVENT_PLAYER_PROFILE_IDS = {

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    31938135: (24696, 91539),
    31938126: (67362,),
    31938118: (184993,),
    31938197: (184993,),
    31938112: (189725,),
    31938163: (189725,),
    31938156: (189844,),

    # 2023 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2023_completion 자료에 있어요.
    88840515: (37595901,),
    88841181: (37620786, 4997513),
    89049488: (4997513,),
    89050131: (196419,),
    89051755: (37595901, 190658),
    89051042: (190658,),

    # 2022 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022_completion 자료에 있어요.
    36225757: (194922,),
    36225763: (2823522,),
    36225764: (37537029,),
    36225765: (32514,),
    36225766: (37439044,),
    36225773: (32514,),
    36225775: (3533335,),
    36183313: (3533335,),
    36183574: (597,),
    36183868: (2823522,),
    36184253: (37537029,),
    36183560: (597,),
    36184066: (37537029,),
    79682441: (32470,),
    36428082: (597,),
    36455868: (2823522,),
    36455869: (37537029,),
    38187647: (2823522,),
    38187650: (194922,),
    38187651: (37537029,),
    38187653: (37563216,),
    38152188: (597,),
    38162320: (194922,),
    38174811: (597,),
    38174814: (3533335,),
    38174817: (194922,),
    38174820: (37537029,),
    39739635: (32514, 37537029),
    39744225: (2823522,),
    41013438: (194922,),
    41020568: (2823522, 32514),
    36140238: (236073,),

    # 2021 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2021_completion 자료에 있어요.
    35401826: (37315895,),
    3002469: (28135,),
    35517954: (190766,),
    35517956: (190766,),
    35517968: (190449,),
    35518042: (2158153,),
    35518112: (177679,),
    3000470: (192069,),
    3000504: (2158153,),
    3000576: (83513, 83374),
    3000829: (192069,),
    3000882: (192069,),
    3000832: (2158153,),
    3001111: (190766,),
    3001534: (190449,),
    3001605: (177679,),
    3000813: (177679,),
    2963675: (2158153,),
    2964088: (190766, 2158153),
    2964089: (190449,),
    2963593: (192069,),
    3100981: (83513,),
    3101083: (192069,),
    3101372: (190449,),
    3101942: (190766, 2158153),
    3101943: (177679,),
    3100569: (190449,),
    3102061: (190766,),
    3102063: (83374,),
    35650441: (190449,),
    35650444: (190449,),
    35650449: (190766,),
    35650451: (177679,),

    # 2020 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2020_completion 자료에 있어요.
    34742639: (190449,),
    34742681: (190449,),
    34742691: (177679, 192069),
    77804788: (177679,),
    34805238: (190320, 190648),
    34805247: (192069,),
    34805255: (190407,),
    34805260: (190449,),
    35030708: (133409,),
    35030664: (366951,),
    35032139: (37540087,),
    35032151: (37540087,),

    # UEFA 경기표의 Mangan 54분 교체예요. 없는 명단·통계는 만들지 않아요.
    32411817: (9541,),
    # 2019 AIK 8경기의 이벤트 배우를 경기 기록·구단 공식 생일 자료와 대조했어요.
    # 프로필만 보충해요. 출처별 분·도움 차이와 없는 명단·통계는 별도 검증 대상으로 남겨요.
    # 근거: outputs/sportmonks-resume-20260921/2019-aik-verified-repairs.json
    33508870: (30547,),
    33508939: (597, 3533335),
    33508951: (30547,),
    33508984: (151043,),
    33508890: (151623,),
    77054661: (151623,),
    33508887: (184993, 151043),
    33508894: (184993,),
    33508906: (597,),
    33508941: (151043, 189844),
    33508977: (30547,),
    33508994: (150343, 184993),
    33508932: (61750,),
    33761426: (184993, 597),
    33761457: (30547,),
    33761468: (151043,),
    33761633: (189844, 597),
    33761649: (597,),
    33761695: (30547,),
    33761696: (193101, 151623),
    33761699: (3533335, 597),
    33761700: (150343, 151122),
    77188762: (597,),
    33962535: (151043, 150343),
    88057650: (32514,),
    88057654: (193101, 151623),
    33962444: (150343,),
    33962318: (32514, 184993),
    33962438: (32514,),
    88057649: (150343,),
    34003376: (32514,),
    34003381: (30547,),
    34003407: (193101, 151623),
    34003360: (597,),
    34003371: (151623,),
    34003505: (597,),
    34003671: (184993,),
    34003697: (3533335, 32514),
    34003756: (193101, 151623),
    34003547: (32514,),
    34003569: (61750,),
    # 2018 Shamrock·Nordsjælland전의 교체·경고와 AIK 공식 생일 자료를 대조했어요.
    # 원문에 AIK 명단이 없어 이벤트 프로필만 보충해요. 분·통계·없는 이벤트는 만들지 않아요.
    # 근거: outputs/sportmonks-resume-20260921/2018-aik-verified-repairs.json
    76472050: (24696,),
    76472035: (134009,),
    32448024: (184993, 134009),
    32448038: (24696,),
    76472112: (151043,),
    76472107: (118443,),
    32448188: (184993,),
    32599058: (193101, 151043),
    32599064: (184993,),
    32599096: (190707,),
    32599164: (61750, 150343),
    32599202: (134009, 184993),
    32599221: (24696,),
    32599284: (597,),
    # Željezničar 원정의 실제 두 교체예요. AIK 명단은 없고, 73분 교체에는 두 프로필이 함께 없어요.
    # 근거: 20260921-2017-zelj-first-verified-repairs.json. 없는 명단·분·통계를 만들지 않아요.
    31937993: (184993, 24696),
    31938010: (189371,),
    # 2017 Braga 홈 89분 교체는 투입 Markkanen·아웃 Goitom의 프로필이 모두 없어요.
    # 같은 실제 이벤트에 두 프로필을 함께 보충하고, 없는 AIK 명단·분·통계는 만들지 않아요.
    31998425: (24696,),
    31998460: (91539, 184993),
    # 2017 Braga 원정의 Obasi 득점·Ishizaki 교체·Johansson 경고와 정확한 생일을 대조했어요.
    # AIK 명단 행이 없어 실제 이벤트 프로필만 보충하고, 명단·분·통계는 만들지 않아요.
    31998453: (30547,),
    31998571: (189371,),
    31998649: (189725,),
    # 2017 Bristol–Palace의 Taylor 득점·도움과 Pisano 교체는 구단 전체 중계와 생일 자료로 확인했어요.
    # 두 선수 명단 행이 없어 해당 이벤트 프로필만 보충하고 명단·분·통계는 만들지 않아요.
    32130965: (7998,),
    32131052: (128981,),
    # 2017 KI–AIK 두 경기에는 AIK 명단 행이 없어요. 실제 교체·득점과 구단 생일 자료를 대조했어요.
    # 확인한 이벤트의 투입·아웃 선수 프로필만 보충하고, 없는 명단·분·통계는 만들지 않아요.
    # iSport 중계 261526/261672, Sky 373939와 AIK·ÖFK 공식 프로필 자료를 함께 확인했어요.
    31875713: (184993,),
    31875715: (190783,),
    31875711: (91539,),
    31875714: (189371,),
    31875719: (458954,),
    31875722: (189844,),
    31875731: (426932,),
    # 실제 명단에서 Marczuk을 확인했지만 공급자에는 해당 선수 슬롯이 없어요.
    # PZPN 2024-07-23 경기와 구단 2024-08-13 경기, RSL 생일·시즌 7번을 대조했어요.
    # 상대 팀 7번 슬롯을 바꾸거나 명단·통계를 새로 만들지 않아요.
    117214871: (37531515,),
    118164492: (37531515,),
    # Motherwell–HB의 78분 교체 선수는 확인되지만 첫 경기 라인업에 17번 행 자체가 없어요.
    # 다음 경기 17번·현재 소속·실제 교체를 대조한 이 이벤트의 프로필만 보충해요.
    # https://www.footballwebpages.co.uk/match/2026-2027/uefa-conference-league/motherwell/hb-torshavn/574647
    157313260: (6234,),
    # Pafos–Salzburg(19766394): 중계·다음 두 경기 33번·단건 생년월일을 대조했어요.
    # https://sport.sky.de/fussball/pafos-vs-salzburg/live/571443
    157460319: (226852,),
    # Partizan–Tobol(19766274): 68분 Lisakovich 교체는 있지만 후보 99번 행이 없어요.
    # 중계·다음 경기 99번·UEFA의 생년월일(1998-02-08)을 대조했어요. 라인업은 만들지 않아요.
    # https://www.skysports.com/football/partizan-belgrade-vs-tobol-kostanay/577228
    157401474: (58436,),
}

# 원문과 검증한 경기 기록을 대조해 잘못된 이벤트 필드만 보정해요.
SPORTMONKS_EVENT_OVERRIDES = {

    # 경기표에서 감독 카드 시간을 확인했어요. 근거는 sportmonks_negative_completion_events.json에 있어요.
    84149823: {'minute': 48, 'extra_minute': None},
    84149825: {'minute': 84, 'extra_minute': None},
    84164002: {'minute': 90, 'extra_minute': 6},
    84164005: {'minute': 90, 'extra_minute': 10},
    88296854: {'minute': 90, 'extra_minute': None},
    88296858: {'minute': 90, 'extra_minute': None},
    88282929: {'minute': 90, 'extra_minute': None},
    88282933: {'minute': 90, 'extra_minute': 7},
    85620209: {'minute': 108, 'extra_minute': None},

    # 2025-semantic 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025-semantic_completion 자료에 있어요.
    152487891: {'related_player_id': 21072805, 'related_player_name': 'Rayan Cherki'},
    152270484: {'type_id': 15, 'type': {'id': 15, 'name': 'Own Goal', 'code': 'owngoal', 'developer_name': 'OWNGOAL', 'model_type': 'event', 'stat_group': None}, 'player_id': None, 'player_name': 'Álvaro Calado', 'related_player_id': None, 'related_player_name': None, 'info': 'Own goal', 'sub_type_id': None},

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    31875164: {'player_id': 91467, 'player_name': 'Rezgar Amani'},

    # 2025 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025_completion 자료에 있어요.
    150689607: {'player_id': None, 'player_name': 'Jorge Simão', 'coach_id': 456302, 'participant_id': 1453, 'minute': 84},
    150725068: {'player_id': None, 'player_name': 'Admir Adžem', 'coach_id': 10275423},
    150725288: {'player_id': None, 'player_name': 'Slaviša Stojanovič', 'coach_id': 6972166},
    150759508: {'related_player_id': 37683336, 'related_player_name': 'Marko Simun'},
    150759947: {'player_name': 'Aleksandar Desančić'},
    150798805: {'player_id': None, 'player_name': 'Nikita Andreev', 'coach_id': 87351},
    150906214: {'player_id': None, 'player_name': 'Edward Iordănescu', 'coach_id': 883002},
    150906604: {'player_id': None, 'player_name': 'Imanol Idiakez', 'coach_id': 456080, 'minute': 89},
    150906550: {'minute': 78},
    152276373: {'player_id': 37702358, 'player_name': 'Pol Fernández Serra', 'related_player_id': 189268, 'related_player_name': 'Alberto Benito'},
    152276755: {'player_id': 37702358, 'player_name': 'Pol Fernández Serra'},
    152269315: {'player_id': 37765709, 'player_name': 'Iker Vadillo'},

    # 2024 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2024_completion 자료에 있어요.
    116763820: {'player_id': 37743072, 'player_name': 'Pape Doudou', 'related_player_id': 37342685, 'related_player_name': 'Cheikh Diouf'},
    116763608: {'player_id': 37342685, 'player_name': 'Cheikh Diouf'},
    116763775: {'player_id': 9938996, 'player_name': 'Ingi Jonhardsson', 'related_player_id': 37324944, 'related_player_name': 'Olaf Bárdarson'},
    116763778: {'player_id': 37324955, 'player_name': 'Jørgen Nielsen', 'related_player_id': 86043, 'related_player_name': 'Finnur Justinussen'},
    146691543: {'player_id': 119534, 'player_name': 'Álvaro Montejo', 'related_player_id': 382366, 'related_player_name': 'Aléx Pérez'},
    146691544: {'player_id': 32002912, 'player_name': 'Monty', 'related_player_id': 122938, 'related_player_name': 'José García'},
    146691545: {'player_id': 37728025, 'player_name': 'Juan Fernández', 'related_player_id': 37594407, 'related_player_name': 'Avelino Sánchez'},
    147342214: {'player_id': 37770864, 'player_name': 'Pedro Luz', 'related_player_id': 37316697, 'related_player_name': 'Jorge Campos'},
    147342520: {'minute': 90, 'player_id': 187216, 'player_name': 'Iván Sánchez', 'related_player_id': 189956, 'related_player_name': 'Anuar'},
    147340598: {'player_id': 37316697, 'player_name': 'Jorge Campos'},
    147340625: {'participant_id': 361, 'player_id': 30866040, 'player_name': 'Lucas Rosa'},
    147342932: {'participant_id': 25833, 'player_id': 33186396, 'player_name': 'Carlos Pascual'},
    147343883: {'player_id': 37544918, 'player_name': 'Adilson Fernandes'},
    147341588: {'minute': 81, 'player_id': 37544918, 'player_name': 'Adilson Fernandes', 'related_player_id': 37654890, 'related_player_name': 'Álex Moreno'},
    147390407: {'coach_id': None, 'player_id': 37669685, 'player_name': 'Álex Carrasco'},
    147396624: {'participant_id': 844, 'player_id': 540248, 'player_name': 'Javi Hernández'},

    # 2023 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2023_completion 자료에 있어요.
    89053520: {'player_id': None, 'coach_id': 86260, 'minute': 90, 'extra_minute': 6},
    89028493: {'related_player_id': 2206769, 'related_player_name': 'Dmitriy Lisakovich'},
    88805494: {'verified_player_profiles': [{'id': 37705392, 'sport_id': 1, 'country_id': 251, 'nationality_id': 251, 'city_id': None, 'position_id': None, 'detailed_position_id': None, 'type_id': None, 'common_name': 'D. Scoccimarro', 'firstname': 'Dennis', 'lastname': 'Scoccimarro', 'name': 'Dennis Scoccimarro', 'display_name': 'Dennis Scoccimarro', 'image_path': 'https://cdn.sportmonks.com/images/soccer/placeholder.png', 'height': 178, 'weight': None, 'date_of_birth': None, 'gender': 'male'}]},
    92181051: {'player_id': 37728177, 'player_name': 'Enrique Márquez'},

    # 2022 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022_completion 자료에 있어요.
    36473456: {'related_player_id': 87172, 'related_player_name': 'Jákup Biskopstø Andreasen'},
    38144722: {'related_player_id': 86656, 'related_player_name': 'Árni Frederiksberg'},
    36225151: {'related_player_id': 86656, 'related_player_name': 'Árni Frederiksberg'},
    39753598: {'related_player_id': 225494, 'related_player_name': 'Eder'},

    # 2021 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2021_completion 자료에 있어요.
    35446115: {'related_player_id': 86656, 'related_player_name': 'Árni Frederiksberg'},
    35446118: {'related_player_id': 86656, 'related_player_name': 'Árni Frederiksberg'},
    29593007: {'player_id': 37595854, 'player_name': 'Adar Azruel'},
    29532965: {'player_id': 37608480, 'player_name': 'Sergio Sanz'},
    87835564: {'minute': 72},
    29532518: {'player_id': 445425, 'player_name': 'Luis Rioja', 'participant_id': 2975},

    # 2019-semantic 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019-semantic_completion 자료에 있어요.
    34003527: {'related_player_id': 172752, 'related_player_name': 'Ryan Christie'},

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    33464536: {'related_player_id': 405156, 'related_player_name': 'Sebastián Gómez'},
    33464580: {'related_player_id': 87172, 'related_player_name': 'Jákup Biskopstø Andreasen'},
    33509244: {'related_player_id': 61511, 'related_player_name': 'Stefan Nikolić'},
    33761703: {'related_player_id': 191216, 'related_player_name': 'Sebastian Starke Hedlund'},
    87637258: {'player_id': 67417, 'player_name': 'Armin Hodžić'},
    33782100: {'related_player_id': 185640, 'related_player_name': 'Javi López'},
    33962875: {'related_player_id': 125015, 'related_player_name': 'Avishay Cohen'},
    34155400: {'related_player_name': 'Roberto Gándara'},

    # 2020 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2020_completion 자료에 있어요.
    34721196: {'related_player_id': 86656, 'related_player_name': 'Árni Frederiksberg'},
    34724757: {'related_player_id': 19960414, 'related_player_name': 'Petar Vukčević'},
    34782210: {'player_id': 474354, 'player_name': 'Mousa Al Tamari'},
    34809443: {'related_player_id': 311129, 'related_player_name': 'Abdulla Yusuf Helal'},
    34742705: {'minute': 33},

    # UEFA 경기표의 Pearson 경고와 Rapid 당일 중계의 Ivan 도움을 반영해요.
    32411868: {'minute': 79},
    32662665: {'related_player_id': 165211, 'related_player_name': 'Andrei Ivan'},
    # Sturm–Slovan 77분 VAR은 78분 퇴장 선수 Weiss(1989년생)예요. 동명이인 감독 ID를 바로잡아요.
    # 근거: outputs/sportmonks-resume-20260921/2023-weiss-verified-repairs.json
    106909083: {"player_id": 3638},
    # UEFA 최종 경기표의 Carcedo 경고는 Pafos 89분이에요. 상대팀 53분으로 섞인 기존 행만 바로잡아요.
    151034631: {"participant_id": 8119, "player_id": None, "coach_id": 37552521, "minute": 89},
    # Slovan 공식 경기표와 당시 중계의 Weiss 감독 경고·두 번째 경고는 별개예요.
    # 두 기존 90+2분 행은 유지하고 감독만 연결해요. 선수 Weiss와는 다른 배우예요.
    150838640: {"player_name": "Vladimir Weiss", "coach_id": 329291},
    150838881: {"coach_id": 329291},
    # Sant Andreu의 59분 두 교체와 승부차기 2·4회차가 다른 배우로 섞였어요.
    # LaLiga 전체 순서와 RFEF 카드를 대조했어요. 실제 Naranjo 8회차·감독 카드는 유지해요.
    152283635: {"player_id": 37640778, "player_name": "Alexis García"},
    152283628: {"related_player_id": 37655317, "related_player_name": "Armand Vallés"},
    152283888: {"player_id": 37640778, "player_name": "Alexis García"},
    152283892: {"player_id": 448466, "player_name": "Max Marcet"},
    152283479: {"player_id": 37771638, "player_name": "Pablo Santiago"},
    152283490: {"player_id": 37543405, "player_name": "Carlos Domínguez"},
    152283729: {"player_id": 37584703, "player_name": "Raúl García-Alejo"},
    # Quintanar–Elche의 실제 64분 교체는 Pedrosa/Nico예요. 별도 Fort/Josan 행은 유지해요.
    152276421: {"related_player_id": 37786133, "related_player_name": "Nico Salvador"},
    # 113분은 Ticiano의 경고예요. LaLiga·RFEF로 구분한 실제 Sarabia 감독 경고는 별도 행에 남겨요.
    152276869: {"player_id": 37761933, "player_name": "Ticiano Pérez"},
    # 양 구단 공식 경기표의 59분 교체는 Gomes/Aitchison, Higgins/Cole이에요. 아웃 배우만 바로잡아요.
    152486474: {"related_player_id": 173158, "related_player_name": "J. Aitchison"},
    152486501: {"related_player_id": 7965, "related_player_name": "R. Cole"},
    # Paks–Cluj의 실제 교체는 Böde/Tóth예요. Cluj의 Samake 교체는 별도 행에 있어요.
    # 구단 경기표와 Sky의 전체 9교체를 대조했고, 원래 73분은 유지해요.
    150695020: {"player_id": 112057, "player_name": "Dániel Böde",
                "related_player_id": 3857295, "related_player_name": "Barna Tóth"},
    # Sarajevo–Craiova의 20분 도움도 같은 Mlinarić예요. 득점·87분 교체는 그대로 둬요.
    150759637: {"related_player_id": 37287261},
    # Roma–Bologna(19662591): UEFA 경기표의 Italiano 경고는 연장 120+3분이에요.
    # 별도 감독 행이 없으므로 기존 행을 보정해요. 실제 Çelik 55분·Mancini 120+3분은 유지해요.
    # https://www.uefa.com/newsfiles/uefacup/2026/2048133_FR.pdf
    156280504: {
        "participant_id": 8513, "player_id": None, "coach_id": 128261,
        "minute": 120, "extra_minute": 3, "period_id": 6856687, "detailed_period_id": 6856703,
    },
    # 연장 후반 시작 때 두 교체의 아웃 선수가 서로 바뀌었어요. 공식 경기표의 짝만 복원해요.
    # Mark/Olivares·Mendoza/Antonio로 연결하고 원래 분·팀·상세는 유지해요.
    147433194: {'related_player_id': 37550717, 'related_player_name': 'Pablo Olivares'},
    147433202: {'related_player_id': 37263412, 'related_player_name': 'Antonio Fernández'},
    # 승부차기 실축 행에 직전 상대 키커가 복사됐어요. 공식 순서의 Ayo·Goyo만 복원해요.
    # 팀·성공 여부·승부차기 순서와 나머지 이벤트는 유지해요.
    147427240: {'player_id': 380611, 'player_name': 'Héctor Ayodele'},
    147427296: {'player_id': 31625657, 'player_name': 'Goyo'},
    # LaLiga·Sant Andreu 공식 경기표와 기존 30·60분 명단으로 확인한 Betis의 다섯 번째 교체예요.
    # 빈 행이 Sant Andreu 72분으로 잘못 묶였어요. 다른 아홉 교체와 기존 행 수는 유지해요.
    147386166: {
        "participant_id": 485,
        "player_id": 37599292,
        "related_player_id": 95269,
        "player_name": "Vitor Roque",
        "related_player_name": "Cédric Bakambu",
        "minute": 60,
    },
    # LaLiga 실제 73분 두 교체를 대조했어요. 상대 팀 이벤트에 섞인 Sofiane을 옮겨 바로잡아요.
    # 근거: 20260921-2024-ceuta-verified-repairs.json. 기존 팀·분·이벤트는 유지해요.
    147425174: {"player_id": 24073451, "player_name": "Sofiane El Ftouhi", "related_player_id": 37547296, "related_player_name": "Martin Bellotti"},
    147425198: {"player_id": 2510665, "player_name": "Jesús Areso", "related_player_id": 188089, "related_player_name": "Nacho Vidal"},
    # 공식 59분 Carrillo/Sarmiento 교체의 빈 투입 연결만 채워요. 실제 같은 경기 7번을 대조했어요.
    147424618: {"player_id": 37587996, "player_name": "Marcos Carrillo"},
    # Logroñés 61분 두 교체의 아웃 선수가 서로 바뀌었어요. 실제 Pau/Riki·Yasin/Monreal 짝만 복원해요.
    147394535: {'related_player_id': 37688121, 'related_player_name': 'Ricardo de Moraes'},
    147394536: {'related_player_id': 445683, 'related_player_name': 'Julen Monreal'},
    # Girona 공식 경기표의 Marco Manchón은 실제 11번 González Martínez예요.
    # 무관한 2005년생 골키퍼 Pérez González와 구분하고 기존 분·아웃 선수는 유지해요.
    # 같은 경기의 빈 67분 행은 공식 Alberto Caro/Tala 교체로 확인했어요.
    122809298: {"player_id": 37551709, "player_name": "Marco Manchón"},
    122810357: {"player_id": 37262667, "related_player_id": 37262730, "player_name": "Alberto Caro", "related_player_name": "Tala"},
    # Jagiellonia 세 경기: PZPN·Onlajny 실제 중계·구단 경기표의 교체짝을 개별 대조했어요.
    # 배우·이름의 투입/아웃 방향만 맞춰요. 출처마다 다른 분과 기존 팀·득점·경고는 유지해요.
    # 근거: 20260920-2024-jagiellonia-three-verified-repairs.json
    117214575: {"player_id": 53505, "related_player_id": 33733, "player_name": "Cheikhou Dieng", "related_player_name": "Federico Palacios"},
    117214578: {"player_id": 9816, "related_player_id": 5283808, "player_name": "Noel Mbo", "related_player_name": "Sivert Gussias"},
    117214871: {"player_id": 382681, "related_player_id": 37531515, "player_name": "Miki Villar", "related_player_name": "Dominik Marczuk"},
    117214874: {"player_id": 155503, "related_player_id": 33165760, "player_name": "Jaroslaw Kubicki", "related_player_name": "Nené"},
    117216492: {"player_id": 23569, "related_player_id": 137172, "player_name": "Jeffrey Sarpong", "related_player_name": "Ernestas Veliulis"},
    117216511: {"player_id": 6006245, "related_player_id": 1477625, "player_name": "Lamine Diaby-Fadiga", "related_player_name": "Afimico Pululu"},
    117216633: {"player_id": 37606836, "related_player_id": 6600015, "player_name": "Nojus Luksys", "related_player_name": "Lucas de Vega"},
    117216641: {"player_id": 530921, "related_player_id": 13185013, "player_name": "Aurélien Nguiamba", "related_player_name": "João Moutinho"},
    117216655: {"player_id": 37460555, "related_player_id": 150531, "player_name": "Wojciech Laski", "related_player_name": "Kristoffer Hansen"},
    117216656: {"player_id": 138424, "related_player_id": 3156919, "player_name": "Markas Beneta", "related_player_name": "Rokas Rasimavicius"},
    117527306: {"player_id": 530921, "related_player_id": 155299, "player_name": "Aurélien Nguiamba", "related_player_name": "Taras Romanczuk"},
    117527307: {"player_id": 33165760, "related_player_id": 188778, "player_name": "Nené", "related_player_name": "Jesús Imaz"},
    117527308: {"player_id": 2823100, "related_player_id": 81228, "player_name": "Dusan Stojinovic", "related_player_name": "Michal Sacek"},
    117527309: {"player_id": 33733, "related_player_id": 6600015, "player_name": "Federico Palacios", "related_player_name": "Lucas de Vega"},
    117527310: {"player_id": 23569, "related_player_id": 137172, "player_name": "Jeffrey Sarpong", "related_player_name": "Ernestas Veliulis"},
    117527867: {"player_id": 5283808, "related_player_id": 9816, "player_name": "Sivert Gussias", "related_player_name": "Noel Mbo"},
    117527868: {"player_id": 138424, "related_player_id": 155602, "player_name": "Markas Beneta", "related_player_name": "Robert Mazan "},
    117527881: {"player_id": 37629806, "related_player_id": 13185013, "player_name": "Jakub Lewicki", "related_player_name": "João Moutinho"},
    117528106: {"player_id": 382681, "related_player_id": 150531, "player_name": "Miki Villar", "related_player_name": "Kristoffer Hansen"},
    117528511: {"player_id": 32062, "related_player_id": 58237, "player_name": "Malcolm Cacutalua", "related_player_name": "Kaspars Dubra"},
    118163946: {"player_id": 33165760, "related_player_id": 530921, "player_name": "Nené", "related_player_name": "Aurélien Nguiamba"},
    118164099: {"player_id": 153021, "related_player_id": 33587412, "player_name": "Sondre Sörli", "related_player_name": "Isak Dybvik Määttä"},
    118164107: {"player_id": 151192, "related_player_id": 151532, "player_name": "Ulrik Saltnes", "related_player_name": "Sondre Fet"},
    118164211: {"player_id": 382681, "related_player_id": 150531, "player_name": "Miki Villar", "related_player_name": "Kristoffer Hansen"},
    118164269: {"player_id": 6006245, "related_player_id": 1477625, "player_name": "Lamine Diaby-Fadiga", "related_player_name": "Afimico Pululu"},
    118164293: {"player_id": 21065103, "related_player_id": 3876679, "player_name": "August Mikkelsen", "related_player_name": "Håkon Evjen"},
    118164343: {"player_id": 151472, "related_player_id": 15061513, "player_name": "Andreas Helmersen", "related_player_name": "Kasper Høgh"},
    118164519: {"player_id": 155503, "related_player_id": 155299, "player_name": "Jaroslaw Kubicki", "related_player_name": "Taras Romanczuk"},
    118164559: {"player_id": 12058670, "related_player_id": 151568, "player_name": "Adam Sørensen", "related_player_name": "Fredrik Bjørkan"},
    118164568: {"player_id": 5283881, "related_player_id": 188778, "player_name": "Tomás Silva", "related_player_name": "Jesús Imaz"},
    # 세 교체의 투입 선수가 서로 섞였어요. 실제 팀·아웃 선수·기존 분은 유지해요.
    # https://www.transfermarkt.com/hapoel-beer-sheva_cherno-more-varna/index/spielbericht/4361875
    117274516: {"player_id": 37308565, "player_name": "Ignacio Pais"},
    117274517: {"player_id": 237188, "player_name": "Déinner Quiñónes"},
    117274560: {"player_id": 28944221, "player_name": "Tomer Yosefi"},
    # MFA가 확인한 자책골 선수는 Sliema의 Gustavo Alcino예요. 득점 수혜 팀은 그대로 둬요.
    # https://matchcentre.mfa.com.mt/articles/general-category/202425-uefa-european-cup-competitions-1/
    117272024: {"player_id": 10319478, "player_name": "Gustavo Alcino"},
    # 구단 경기 기록으로 기존 교체 두 개의 빈 투입 선수만 확인했어요.
    # https://fckryvbas.com/post/viktoriya-plzen-krivbas-1-0
    118221180: {"player_id": 1148, "player_name": "Matěj Vydra"},
    118221181: {"player_id": 37317381, "player_name": "Oleksandr Drambayev"},
    # Marsaxlokk의 실제 81분·96분 교체 방향과 선수는 경기 명단으로 확인했어요.
    # https://talk.mt/conf-lge-goal-fil-hin-mizjud-jelimina-lil-marsaxlokk/
    116969743: {"player_id": 144611, "related_player_id": 256798, "player_name": "Jacob Walker", "related_player_name": "Igor Goularte"},
    116970646: {"player_id": 37405046, "related_player_id": 73991, "player_name": "Patrick Nonato", "related_player_name": "Jefferson"},
    # Mornar 1차전의 기존 교체 7개는 투입·아웃이 뒤집혔어요. 71분 투입은 Ćetković예요.
    # https://www.uefa.com/news-media/mediaservices/informationkits/competitions/uefaconferenceleague/2025/match/2041029/
    116767484: {"player_id": 37668731, "related_player_id": 37600801, "player_name": "S. Samushia", "related_player_name": "N. Tsetskhladze"},
    116767485: {"player_id": 83863, "related_player_id": 37332625, "player_name": "Davit Skhirtladze", "related_player_name": "Nodar Lominadze"},
    116768248: {"player_id": 37735725, "related_player_id": 110204, "player_name": "Kotaro Kishi", "related_player_name": "Darko Zoric"},
    116768313: {"player_id": 35659820, "related_player_id": 24818170, "player_name": "Giorgi Moistsrapishvili", "related_player_name": "Levan Osikmashvili"},
    116768329: {"player_id": 37598903, "related_player_id": 37668730, "player_name": "J. Iobashvili", "related_player_name": "Vakhtang Salia"},
    116768328: {"player_id": 49658, "related_player_id": 37347605, "player_name": "Marko Ćetković", "related_player_name": "Balša Dubljević"},
    116768352: {"player_id": 69499, "related_player_id": 37605191, "player_name": "Ermin Seratlić", "related_player_name": "Balša Vukotić"},
    # 2차전도 각 교체 짝을 따로 확인했어요. 보도마다 차이 나는 분은 기존 값을 유지해요.
    # https://www.vijesti.me/sport/fudbal/716476/podvig-u-tbilisiju-mornar-vjeruje-u-snove-ostvario-ih-protiv-dinama
    116968311: {"player_id": 37600801, "related_player_id": 37668730, "player_name": "N. Tsetskhladze", "related_player_name": "Vakhtang Salia"},
    116969087: {"player_id": 37598903, "related_player_id": 83863, "player_name": "J. Iobashvili", "related_player_name": "Davit Skhirtladze"},
    116969387: {"player_id": 49658, "related_player_id": 110204, "player_name": "Marko Ćetković", "related_player_name": "Darko Zoric"},
    116969809: {"player_id": 37332625, "related_player_id": 37356526, "player_name": "Nodar Lominadze", "related_player_name": "Dominique Celidor Simon"},
    116970064: {"player_id": 37668731, "related_player_id": 24818170, "player_name": "S. Samushia", "related_player_name": "Levan Osikmashvili"},
    116970099: {"player_id": 37735725, "related_player_id": 179886, "player_name": "Kotaro Kishi", "related_player_name": "Marko Đurišić"},
    116970154: {"player_id": 538316, "related_player_id": 37347605, "player_name": "Veljko Trifunovic", "related_player_name": "Balša Dubljević"},
    # 69분 경고는 Hamrun의 1989년생 Eder예요. 무관한 Geder 연결만 바꿔요.
    # https://sport.timesofmalta.com/2024/07/16/watch-spartans-pay-the-penalty-as-lincoln-red-imps-progress-after-shoot-out-win/
    116912418: {"player_id": 225494, "player_name": "Eder"},
    # FSF 공식 경기표로 경고·교체를 확인했어요. 106분 투입은 20번 Børge예요.
    # Hrelja는 78분에 나간 뒤 87분에 경고받아 후반 구간으로 함께 맞춰요.
    # https://www.fsf.fo/wp-content/uploads/2025/04/Arsfragreidingin_2024_15-04-2025.pdf (247쪽)
    118227335: {"player_id": 86656, "player_name": "Árni Frederiksberg"},
    118228127: {"related_player_id": 73219, "related_player_name": "Zoran Kvržić"},
    118228128: {"related_player_id": 518625, "related_player_name": "Nikola Srećković"},
    118228129: {"related_player_id": 37568220, "related_player_name": "Damir Hrelja"},
    118233243: {"player_id": 21782198, "player_name": "Børge Petersen"},
    118229656: {"minute": 87, "period_id": 5542180},
    # Celje–Başakşehir(19296501): 퇴장은 명단에 없는 Hiltunen이 아니라 같은 경기 감독 Atan이에요.
    # https://beinsports.com.tr/haber/uefa-konferans-ligi-celje-basaksehir
    156508153: {"player_id": None, "player_name": "Çagdas Atan", "coach_id": 30462},
    # TNS–Astana(19296510): 구단 공식 기록의 43분 경고는 감독 Craig Harrison에게 주어졌어요.
    # https://tnsfc.co.uk/event/the-new-saints-fc-vs-astana/
    156508154: {"player_id": None, "player_name": "Craig Harrison", "coach_id": 455867},
    # Chiclana의 실제 58분 교체는 Popi 투입·Mawi 아웃이에요. 무관한 Joaqui 연결만 바로잡아요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-chiclana-cf-ca-osasuna-2
    123171988: {"player_id": 37549740, "related_player_id": 383937, "related_player_name": "Mawi"},
    # Parla전의 빈 교체 두 개는 Fuentes/Manu와 Valencia의 Tejón/Valera예요.
    # 공식 경기 기록·양 팀 명단과 전체 교체 순서를 대조했고 기존 분·이벤트 ID는 유지해요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-cp-parla-escuela-valencia-cf-2
    146966442: {"player_id": 37263972, "related_player_id": 37786931, "player_name": "Miguel Fuentes", "related_player_name": "Manu García"},
    146966669: {"participant_id": 214, "player_id": 37608123, "related_player_id": 7698447, "player_name": "Martín Tejón", "related_player_name": "Germán Valera"},
    # Velež 1차전은 교체 투입·아웃이 뒤집혔어요. 협회 기록으로 확인한 이벤트만 바로잡아요.
    # https://www.nfsbih.ba/vijesti/nogomet-m/wwin-liga-bih/velez-remizirao-sa-inter-escaladsom/
    116753853: {"player_id": 65739, "related_player_id": 37287261, "player_name": "N. Haskić", "related_player_name": "Mihael Mlinaric"},
    116754110: {"player_id": 37457529, "related_player_id": 2148026, "player_name": "Elzio Lohan", "related_player_name": "Dino Halilovic"},
    116754113: {"player_id": 37530358, "related_player_id": 24082533, "player_name": "Ante Orec", "related_player_name": "Karlo Isasegi"},
    116754330: {"player_id": 151561, "related_player_id": 67937, "player_name": "Milan Jevtović", "related_player_name": "O. Pršeš"},
    # 2차전도 경기 기록을 따로 대조했어요. Oreč의 교체·득점·경고 연결도 함께 맞춰요.
    # https://www.vijesti.ba/clanak/650896/uzivo-inter-escaldes-velez-poznati-sastavi-timova
    # https://www.skysports.com/football/inter-club-descaldes-vs-velez-mostar/teams/506708
    116964930: {"player_id": 37430168, "related_player_id": 23269744, "player_name": "Adin Bajric", "related_player_name": "N. Savić"},
    116965958: {"player_id": 73606, "related_player_id": 66250, "player_name": "Tonći Mujan", "related_player_name": "Asmir Suljić"},
    116965974: {"player_id": 37530358, "related_player_id": 2148026, "player_name": "Ante Orec", "related_player_name": "Dino Halilovic"},
    116965981: {"player_id": 151561, "related_player_id": 65739, "player_name": "Milan Jevtović", "related_player_name": "N. Haskić"},
    116966176: {"player_id": 37457529, "related_player_id": 37287261, "player_name": "Elzio Lohan", "related_player_name": "Mihael Mlinaric"},
    116966101: {"player_id": 37530358},
    116964944: {"player_id": 37530358, "player_name": "Ante Orec"},
    # Caernarfon의 4분 득점자는 2000년생 Morgan Rhys Wyn Owen이에요. 동명이인과 구분해요.
    # https://crusadersfootballclub.com/news/crusaders-beaten-by-caernarfon-town-in-1st-leg-tie-2
    116764974: {"player_id": 37410229},
    # LASK전 하프타임에 교체된 Popa는 실제 선발 19번이에요. 이벤트의 미제공 ID만 맞춰요.
    # https://www.digisport.ro/fotbal/europa-league/n-au-stat-pe-ganduri-schimbarile-facute-de-cei-de-la-fcsb-la-pauza-meciului-cu-lask-linz-3127675
    118609805: {"related_player_id": 165624},
    # 같은 경기의 39분 득점도 위 선발 47번으로 연결해요. 도움·시각은 유지해요.
    # https://website-2021.kaagent.be/nl/team/games/uefa-conference-league-voorrondes/6/hibernian-fc/kaa-gent/live
    157653838: {"player_id": 37765373, "player_name": "Josué Vergara"},
    # Rapid전의 22번은 다른 세 경기·현재 스쿼드와 같은 Gómez예요. 해당 경기의 다른 ID만 맞춰요.
    # 1차전 86분 Andy 교체도 같은 선수예요. 교체 상대를 잘못된 동명이인으로 남기지 않아요.
    157312532: {"related_player_id": 37718055},
    157351480: {"related_player_id": 37718055},
    157351924: {"related_player_id": 37718055},
    157351961: {"player_id": 37718055},
    # Penybont전의 득점·교체도 위에서 확인한 같은 경기 22번으로 연결해요.
    # 2009년생 동명이인의 이벤트 ID만 바꾸고 시각·득점·교체 상대는 보존해요.
    157280233: {"player_id": 37718055},
    157254481: {"related_player_id": 37718055},
    # NSÍ전 Adrović의 교체·두 도움도 확인한 후보 26번과 같은 ID로 맞춰요.
    # https://www.livesoccertv.com/es/match/nsi-vs-koper/1rzaet
    157313258: {"player_id": 38218953},
    157313281: {"related_player_id": 38218953},
    157313303: {"related_player_id": 38218953},
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

# 경기 명단과 대조해 잘못 추가된 것으로 확인한 슬롯만 제외해요.
SPORTMONKS_DUPLICATE_LINEUP_IDS = {

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    6936027048,

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    3740369307,
    6835724651,
    6835724711,
    6835724754,
    6835728250,
    6835752980,
    6835752997,

    # Genoa–Entella의 실제 후보·교체를 확인했어요. 통계가 있는 행은 보존해요.
    3752027921,
    3752027940,
    6889084666,
    6889085491,
    6889087369,
    # Vic–Atlético(19320855): 공식 후보 Taulats는 1번이에요. 빈 99번 복제만 제외해요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-ue-vic-atletico-de-madrid-2
    14673342218,
    # Las Rozas–Sevilla(19320860): 매체별 등번호가 달라 LaLiga 공식 명단의 Izan 26번을 유지해요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-las-rozas-cf-sevilla-fc-2
    14673342220,
    # Stuttgart–Sparta(19296219): 공식 명단의 Olivier는 후보 31번이에요.
    # 통계가 없는 14번 복제 슬롯만 제외하고 12779959080은 유지해요.
    # https://www.vfb.de/de/vfb/profis/saison/champions-league/2425/2-vfb-stuttgart----ac-sparta-prag-/
    14673342053,
    # Man City–Sparta(19296251): UEFA 명단의 Surovčík은 후보 44번이에요.
    # 통계가 없는 144번 복제 슬롯만 제외하고 13253150258은 유지해요.
    # https://www.uefa.com/newsfiles/UCL/2025/2041962_SPS.pdf
    14673342054,
    # Tobol–Zrinjski(18601656): 공식 명단의 Jovancic은 29번이에요.
    # 19번 슬롯은 같은 선수·통계가 복제됐어요. 누락된 45번 Amanovic으로 바꾸지 않아요.
    6260405637,
    # Tre Penne–Gjilani(16858563)의 후보 골키퍼 Lanzoni는 공식 경기 기록상 33번이에요.
    # 출전 통계가 없는 중복 92번만 제외해요. 33번 슬롯(6355011103)은 유지해요.
    # https://www.fsgc.sm/assets/documents/553.pdf
    889793873,
    # Kairat–Atlantas(1818704)의 Filipavičius는 19번(6955683516) 한 명이에요. 중복된 26번만 제외해요.
    # https://www.uefa.com/uefaeuropaleague/match/2021717--kairat-almaty-vs-atlantas/lineups/
    1051955850,
    # PAOK–Olimpik Donetsk(3239881)의 Koulouris는 후보 20번(4414061)이에요. 중복된 24번만 제외해요.
    # https://www.uefa.com/uefaeuropaleague/match/2021932--paok-vs-olimpik-donetsk/lineups/
    6942876784,
    # Crvena Zvezda–Spartaks(10336108)의 Jevtović는 후보 26번(6911344591)이에요. 중복된 33번만 제외해요.
    # https://www.uefa.com/uefachampionsleague/match/2024621--crvena-zvezda-vs-spartaks-jurmala/lineups/
    3742326449,
    # PAOK–Basel(10336081)의 Warda는 교체 출전한 74번(5269236)이에요. 중복된 24번만 제외해요.
    # https://www.uefa.com/uefachampionsleague/match/2024635--paok-vs-basel/lineups/
    6911426630,
    # Osijek–Petrocub(10336772)의 Straistari는 후보 33번(885975121)이에요. 중복된 12번만 제외해요.
    # https://www.uefa.com/uefaeuropaleague/match/2024723--osijek-vs-petrocub/lineups/
    6911001837,
    # Tobol–Pyunik(10364831): Hovsepyan의 출전 통계가 없는 55번 중복을 제외하고 아래에서 등번호를 맞춰요.
    # https://es.uefa.com/uefaeuropaleague/match/2024815--tobol-vs-pyunik/lineups/
    6901624204,
    # LASK–Lillestrøm(10336737)의 Celic은 후보 43번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2024817--lask-vs-lillestrom/lineups/
    3742326281,
    # Hajduk–Slavia Sofia(10364869)의 Duka는 후보 1번, Delić는 교체 출전한 19번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2024833--hajduk-split-vs-slavia-sofia/lineups/
    3752110533,
    3752110521,
    # B36–Beşiktaş(10365162)의 Gilli Samuelsen은 후보 17번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2024820--b36-torshavn-vs-besiktas/lineups/
    3752109879,
    # Trenčín–Górnik(10364864)의 Pišoja는 후보 28번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2024854--trencin-vs-gornik-zabrze/lineups/
    3752109988,
    # Trenčín–Feyenoord(10410277)의 Mašović는 후보 33번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2025346--trencin-vs-feyenoord/lineups/
    3752098164,
    # Spartak Subotica–Brøndby(10411086)의 Lučić는 후보 96번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2025348--spartak-subotica-vs-brondby/lineups/
    3752096592,
    # Craiova–Leipzig(10411055)의 Müller는 후보 21번이에요.
    # https://www.uefa.com/uefaeuropaleague/match/2025388--u-craiova-vs-leipzig/lineups/
    3741176096,
    # Žalgiris–Sevilla(10411097)의 Vaclík은 선발 13번이에요. 두 슬롯의 90분 기록은 같아요.
    # https://www.uefa.com/uefaeuropaleague/match/2025375--zalgiris-vs-sevilla/lineups/
    5678907,
    # Glentoran–TNS(18151433)의 Glendinning은 후보 33번이에요. 통계가 없는 중복 32번만 제외해요.
    # https://www.footballtoday.net/livescore/7797227867097917093-glentoran-vs-the-new-saints
    6334982808,
    # Domžale–Swift(18151449)의 Vuk은 후보 89번이에요. 통계가 없는 중복 88번만 제외해요.
    # https://donfutbolisto.com/es/partido/domzale-swift-hesperange-conference-league-08-07-2021/
    6334975898,
}

SPORTMONKS_LINEUP_FIELD_OVERRIDES = {

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    884743352: {'player_name': 'Rezgar Amani'},

    # 2025 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025_completion 자료에 있어요.
    14670350584: {'player_name': 'Aleksandar Desančić'},
    14670618905: {'player_name': 'Cameron Ashia'},
    14670618907: {'player_name': 'Daniel Vost'},
    14671668526: {'player_name': 'Alberto Benito'},
    14671668527: {'player_name': 'Pol Fernández Morales'},
    14671668544: {'player_name': 'Pol Fernández Serra'},
    14671656011: {'player_name': 'Iván Pérez'},
    14671656023: {'player_name': 'Víctor Charlez'},
    14671656414: {'player_name': 'Iker Vadillo'},

    # 2024 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2024_completion 자료에 있어요.
    10957342948: {'player_name': 'Pape Doudou'},
    13894047243: {'player_name': 'Monty'},
    13894047259: {'player_name': 'Avelino Sánchez'},
    13894047257: {'player_name': 'José García'},
    13894047253: {'player_name': 'Aléx Pérez'},
    13894047238: {'player_name': 'Juan Fernández'},
    14174750794: {'player_name': 'Álex González'},
    14174750792: {'player_name': 'Rufo Sánchez'},
    14174750787: {'player_name': 'Rares Mezdrea'},
    14148115875: {'player_name': 'Ibrahim Doumbia'},
    14148115873: {'player_name': 'Carlos Pascual'},
    14148119059: {'player_name': 'Adilson Fernandes'},
    14148119067: {'player_name': 'César Llopis'},
    14148119060: {'player_name': 'Adri Carrión'},
    14148115877: {'player_name': 'Fer Díaz'},
    14148115881: {'player_name': 'Jorge Campos'},
    14148119063: {'player_name': 'Pedro Luz'},
    14175574389: {'player_name': 'Goma'},
    14175574292: {'player_name': 'Álex Carrasco'},

    # 2023 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2023_completion 자료에 있어요.
    5317543729: {'player_name': 'Sergio Álvarez'},
    5317543739: {'player_name': 'Enrique Lotar'},
    5736304269: {'player_name': 'Diego Peláez'},
    5732404495: {'player_name': 'Germán Rodríguez Rojas'},

    # 2022-barbadas 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022-barbadas_completion 자료에 있어요.
    6657953537: {'player_name': 'Pana'},
    6657951925: {'player_name': 'Xinzo'},
    6657953562: {'player_id': None, 'player': None, 'player_name': 'Hugo Iriarte'},

    # 2022 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022_completion 자료에 있어요.
    6259787052: {'player_name': 'Portu'},
    6259786803: {'player_name': 'Antonio Millán'},
    867462095: {'player_name': 'Joki'},
    6259780207: {'player_name': 'Chechu'},
    6259780190: {'player_name': 'Marcus Rowley'},
    6259780205: {'player_name': 'Yerai Rojas'},
    6259778404: {'player_name': 'Christian Montes'},
    6259778507: {'player_name': 'José Luis Gil'},
    6259776760: {'player_name': 'José Antonio Ángel'},
    875437532: {'player_name': 'Lautaro Spatz'},
    6259776757: {'player_name': 'Iván Pérez'},
    6259776782: {'player_name': 'Manín'},
    867833361: {'player_name': 'Khalifa'},
    996187170: {'player_name': 'Manín'},
    6656844548: {'player_name': 'Martín Lamelas'},
    6259773988: {'player_name': 'Guillermo Alonso'},
    993425863: {'player_name': 'Caturla'},
    6259739616: {'player_name': 'Fran López'},
    6259738017: {'player_name': 'Alexis Chamorro'},
    993409344: {'player_name': 'Arpón'},
    993409341: {'player_name': 'Míchel González'},
    993409362: {'player_name': 'David Ruiz'},
    992950100: {'player_name': 'Sampedro'},
    6259737885: {'player_name': 'Leo Ramírez'},
    6259749338: {'player_name': 'Piojo'},
    990822056: {'player_name': 'Pepe Carmona'},
    6259749091: {'player_name': 'Mano Tata'},
    990511997: {'player_name': 'Pitu'},
    6656825461: {'player_name': 'Dieguito'},
    6656825463: {'player_name': 'Germán Martín'},
    995619925: {'player_name': 'Capa'},
    6259742273: {'player_name': 'Garcí'},
    6259653538: {'player_name': 'Capa'},
    6259653347: {'player_name': 'Ousmane Traoré'},
    6259653895: {'player_name': 'Garcí'},
    6259653892: {'player_name': 'Karim El Kounni'},
    6259653894: {'player_name': 'Daniel Santamaria'},
    6259653897: {'player_name': 'Miguel Nieto'},
    6259653883: {'player_name': 'Carmelo Merenciano'},
    1031433425: {'player_name': 'Boubacar Keita'},
    6652473381: {'player_name': 'Curro Bonilla'},
    1032822500: {'player_name': 'Dani Parra'},

    # 2021 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2021_completion 자료에 있어요.
    1054366: {'player_name': 'Amin Mohamed'},
    1129823: {'player_name': 'Omar Sampedro'},
    1183422: {'player_name': 'Jeff King'},
    1368906: {'player_name': 'Mattias Andersson'},

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    888349991: {'jersey_number': 15},
    7790809: {'player_name': 'Brahim Amar Romero'},
    7790797: {'player_name': 'Bilal Amar Ahmed'},
    7790520: {'player_name': 'Álex Diéguez'},
    7791168: {'player_name': 'Nacho Cordero'},
    6265060853: {'player_name': 'Roberto Gándara'},
    6265062320: {'player_name': 'Jon Fernández'},

    # 2020 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2020_completion 자료에 있어요.
    9451635: {'player_name': 'Matteo Scozzarella', 'position_id': 26},
    9547380: {'player_name': 'George Lloyd'},
    9451622: {'player_name': 'Bruno Alves'},

    # 2018 경기 당시 등번호와 포지션을 맞춰요. 근거는 sportmonks_2018_completion_lineups.json에 있어요.
    6402565481: {'jersey_number': 27},
    6402566881: {'jersey_number': 22, 'player_name': 'Mauro Vigorito'},
    6577279542: {'jersey_number': 20},
    6402568739: {'jersey_number': 8, 'player_name': 'Marco Mancosu'},
    6402566897: {'jersey_number': 11, 'player_name': 'Giuseppe Torromino'},
    6402565928: {'position_id': 24, 'formation_position': 1},
    6402568667: {'position_id': 26, 'formation_position': 5},
    6402568745: {'jersey_number': 8, 'position_id': 26},
    6402566856: {'position_id': 25},
    6402566870: {'jersey_number': 9},
    6402565968: {'jersey_number': 29},
    3752027923: {'jersey_number': 30},
    3752027912: {'jersey_number': 19},
    3752027914: {'jersey_number': 24},
    3752027908: {'jersey_number': 23},
    3752027938: {'jersey_number': 29},
    6170002: {'player_name': 'Mitchell Rose'},
    # 미출전 Warlow의 45분·골키퍼 실점만 잘못 붙었어요. 실제 벤치 퇴장 상세는 그대로 남겨요.
    # Opta는 이 시즌 유럽대회 0출전·0분·1퇴장이고, 실제 교체 10쌍에도 Warlow는 없어요.
    14670316645: {"details": [{
        "id": 1592383783, "fixture_id": 19427802, "player_id": None,
        "team_id": 1614, "lineup_id": 14670316645, "type_id": 83, "data": {"value": 1},
    }]},
    # Borac전의 미출전 21번 Pætur에게 20번 Børge의 14분이 복사됐어요. 실제 후보는 유지해요.
    # FSF 공식 경기표 247쪽은 106분 투입을 20번으로 명시해요.
    11640887222: {"details": []},
    # Vic의 실제 골키퍼는 Mora 한 명이고 교체 5명도 모두 필드 선수예요.
    # 미출전 후보 Taulats에 잘못 붙은 46분·선방·평점 등만 비우고 실제 후보 명단은 유지해요.
    # https://www.laliga.com/partido/temporada-2024-2025-copa-del-rey-ue-vic-atletico-de-madrid-2
    13454844342: {"details": []},
    10494668: {"player_name": "Billy Kirkman"},
    6671246635: {"player_name": "Joshua Lock"},
    6671246627: {"player_name": "Nicholas Grogan"},
    10515769: {"player_name": "Billy Kirkman"},
    6671209172: {"player_name": "Joshua Lock"},
    6671209080: {"player_name": "Nicholas Grogan"},
    6671225507: {"player_name": "Atiljo Hoxha"},
    6671231843: {"player_name": "Alan Neri"},
    10517984: {"player_name": "Genís Soldevila Solduga"},
    10518089: {"player_name": "Jordi Betriu Armengol"},
    6260413661: {"player_name": "Jesús Coca Noguerol"},
    6260413124: {"player_name": "Ángel Pérez de la Torre"},
    10522078: {"player_name": "Isi Manellari"},
    6691075816: {"player_name": "Segerso Geci"},
    6260817232: {"player_name": "Joachim Clydio Amijekori"},
    10522084: {"player_name": "Emmanuel Françoise"},
    6260816878: {"player_name": "Dinan Amiri"},
    6260817214: {"player_name": "Kévin Nakache"},
    6260817234: {"player_name": "Boris Olivier Tiotio Bassene"},
    6260817051: {"player_name": "Adrian Ahmetxjekaj"},
    6260816964: {"player_name": "Kenan Ndenge"},
    6671276205: {"player_name": "Helesh Yaroslav"},
    53020118: {"player_name": "Krisztian Nagy"},
    196366601: {"player_name": "Carlos da Cruz"},
    6665561918: {"player_name": "Francisco Ninte Junior"},
    6665562506: {"player_name": "Jocelino Silva Dos Santos"},
    353358802: {"player_name": "Adam Dvořák"},
    6661508862: {"player_name": "Martin Šubert"},
    6661502043: {"player_name": "Albert Labik"},
    591945206: {"player_name": "Adam Dvořák"},
    6661476582: {"player_name": "Martin Šubert"},
    6661477465: {"player_name": "Albert Labik"},
    653673135: {"player_name": "Amir Ganah"},
    6661527741: {"player_name": "Eric Khalfin"},
    10465179: {"player_name": "David Alberto Bautista Martos"},
    6692206577: {"player_name": "Pablo Manuel Rosa Tristán"},
    6692206574: {"player_name": "Manuel Caballero González"},
    6692208387: {"player_name": "Christian Aznar Fernández"},
    10465437: {"player_name": "Marc Priego Masso"},
    6260863316: {"player_name": "Gerard Aloy Soler"},
    6260862840: {"player_name": "Faysal Choaib Hassany"},
    6260862852: {"player_name": "Gonçalo José Gonçalves Paulino"},
    6260862842: {"player_name": "Sergio Clen Mendoza Espíndola"},
    6260862441: {"player_name": "Juan Camilo Puentes Londoño"},
    6260863322: {"player_name": "Monsif Khttar El Yousfi"},
    6260862838: {"player_name": "Joel Paredes Leones"},
    6260862609: {"player_name": "Tiago Venâncio Alves Pires"},
    6692182002: {"player_name": "Francisco Javier Casares García"},
    6691093412: {"player_name": "David Alberto Bautista Martos"},
    6691093123: {"player_name": "Pablo Manuel Rosa Tristán"},
    6691095216: {"player_name": "Manuel Caballero González"},
    6691095214: {"player_name": "Christian Aznar Fernández"},
    10493249: {"player_name": "Ishmael Kofi Antwi"},
    10493371: {"player_name": "Kristjan Mani"},
    6691079760: {"player_name": "Gianmaria Landi"},
    10493458: {"player_name": "Isi Manellari"},
    6691079132: {"player_name": "Segerso Geci"},
    10494002: {"player_name": "Joachim Clydio Amijekori"},
    10493942: {"player_name": "Emmanuel Françoise"},
    6260824785: {"player_name": "Dinan Amiri"},
    6260824719: {"player_name": "Kévin Nakache"},
    6260824783: {"player_name": "Kenan Ndenge"},
    6260822967: {"player_name": "Lohan Pascal Dewalque"},
    6260822232: {"player_name": "Adrian Ahmetxjekaj"},
    6260821765: {"player_name": "Boris Olivier Tiotio Bassene"},
    6671252280: {"player_name": "Antonio Pellegrino"},
    6671250585: {"player_name": "Atiljo Hoxha"},
    6671251267: {"player_name": "Alan Neri"},
    10493694: {"player_name": "Genís Soldevila Solduga"},
    6260401337: {"player_name": "Jordi Betriu Armengol"},
    6260401714: {"player_name": "Jesús Coca Noguerol"},
    6260401716: {"player_name": "Ángel Pérez de la Torre"},
    10437871: {"player_name": "David Alberto Bautista Martos"},
    6260859479: {"player_name": "Manuel Caballero González"},
    6260859481: {"player_name": "Salvador Manuel Alegre Delgado"},
    6260858781: {"player_name": "Connor Peters"},
    6260858777: {"player_name": "Federico Martín Villar"},
    6260858779: {"player_name": "Domingo Jesús Ferrer López"},
    10442022: {"player_name": "Alef Firmino dos Anjos"},
    6692223307: {"player_name": "Amrush Bujupi"},
    6692223310: {"player_name": "Aulon Shabani"},
    10464950: {"player_name": "Alef Firmino dos Anjos"},
    6692218649: {"player_name": "Amrush Bujupi"},
    6692218092: {"player_name": "Aulon Shabani"},
    10441745: {"player_name": "Eros Grani"},
    6390378188: {"player_name": "Joel Núñez"},
    6390377761: {"player_name": "Lorenzo Fabbri"},
    6390377751: {"player_name": "Mirko Mantovani"},
    6390378186: {"player_name": "Mario Ferri"},
    6390377763: {"player_name": "Giacomo Procacci"},
    6390377443: {"player_name": "Federico Ciccione"},
    6390378164: {"player_name": "Pasquale Lo Russo"},
    6390378182: {"player_name": "Alex Castagnoli"},
    6260851287: {"player_name": "Eros Grani"},
    6260851640: {"player_name": "Joel Núñez"},
    6260853112: {"player_name": "Lorenzo Fabbri"},
    6260852289: {"player_name": "Mirko Mantovani"},
    6260852311: {"player_name": "Mario Ferri"},
    6260853114: {"player_name": "Giacomo Procacci"},
    6260852324: {"player_name": "Federico Ciccione"},
    6260853073: {"player_name": "Pasquale Lo Russo"},
    6260853120: {"player_name": "Alex Castagnoli"},
    6692240787: {"player_name": "Mirche Stoilov"},
    6692239602: {"player_name": "Spase Terziev"},
    6692240785: {"player_name": "Martin Gjorgievski"},
    6692240791: {"player_name": "Filip Kupanov"},
    10464655: {"player_name": "Aleix Cisteró Serna"},
    6260860132: {"player_name": "Jorge Bolivar Cano"},
    6260860120: {"player_name": "Javier Morales Aguilera"},
    6260860137: {"player_name": "David Rodríguez López"},
    6692195733: {"player_name": "Daniel Moreno Fernández"},
    6692194396: {"player_name": "Francisco Javier Paul Curado"},
    6692194389: {"player_name": "Luis McCoy"},
    6692195735: {"player_name": "Christian Orihuela Valle"},
    6692195721: {"player_name": "Manuel Román Salado"},
    10442144: {"player_name": "Anis Ćosić"},
    6692211184: {"player_name": "Bakir Rekić"},
    6692212353: {"player_name": "Kasim Sejdinović"},
    41945831: {"player_name": "Amar Meljaki"},
    6672115341: {"player_name": "Umerfaruk Sulejman"},
    6672112605: {"player_name": "Sufjan Chajani"},
    6672113368: {"player_name": "Anid Abazi"},
    52506219: {"player_name": "Carlos da Cruz"},
    6672130304: {"player_name": "Francisco Ninte Junior"},
    6672136329: {"player_name": "Jocelino Silva Dos Santos"},
    6672136316: {"player_name": "Evann Mendes"},
    10459964: {"player_name": "Francisco Ninte Junior"},
    10459966: {"player_name": "Jocelino Silva Dos Santos"},
    10459967: {"player_name": "Hugo Antunes"},
    10462078: {"player_name": "Billy Kirkman"},
    6692161298: {"player_name": "Joshua Lock"},
    6691369037: {"player_name": "Jocelino Silva Dos Santos"},
    6691369147: {"player_name": "Hugo Antunes"},
    10515848: {"player_name": "Carlos da Cruz"},
    6691366149: {"player_name": "Francisco Ninte Junior"},
    6691366969: {"player_name": "Jocelino Silva Dos Santos"},
    6691366962: {"player_name": "Hugo Antunes"},
    10516096: {"player_name": "Amar Meljaki"},
    6691362785: {"player_name": "Anid Abazi"},
    444323: {"player_name": "Ivan Ignatyev"},
    # Bejan은 미출전 후보예요. 복사된 선발 위치만 비우고 Sergiu의 90분 기록은 보존해요.
    10023004: {"player_name": "Alexandru Bejan", "type_id": 12,
               "position_id": None, "formation_position": None},
    6750256861: {"player_name": "Evan da Costa e Sousa"},
    # 협회 명단에 맞춰 두 등번호를 바로잡아요. 10분 출전 기록은 Ledio에게 남겨요.
    368970: {"jersey_number": 22},
    6750272726: {"jersey_number": 7, "player_name": "Fabjan Beqja"},
    # Kent는 미출전 후보예요. 9번 Defoe의 24분·골·도움은 원래 슬롯에만 남겨요.
    # https://www.skysports.com/football/l-red-imps-vs-rangers/teams/434183
    9176738: {"player_name": "Ryan Kent", "details": []},
    6773992085: {"player_name": "Dennis Stojković"},
    # 위에서 확인한 두 선수의 슬롯 이름도 올바른 단건 프로필과 맞춰요.
    8985783: {"player_name": "Gonçalo Jorge Almeida da Silva"},
    6785920623: {"player_name": "Dennis Stojković"},
    # Tobol–Pyunik의 Hovsepyan은 UEFA 명단상 55번으로 62분에 교체 투입됐어요.
    # 28분 출전 통계가 붙은 슬롯을 남겨 통계는 보존하고 등번호만 바로잡아요.
    3752110889: {"jersey_number": 55},
    # Celje의 6번은 후보였어요. 잘못 복사된 선발 수비수의 위치는 비워요.
    # 실제 교체 후 위치는 기록에서 확인되지 않아 프로필 포지션으로 추정하지 않아요.
    8959747: {"type_id": 12, "position_id": None, "formation_position": None,
              "player_name": "Nino Pungaršek"},
}

# 11875057의 11번은 75분에 퇴장했어요. 잘못 복사된 Ivan의 83분을 쓰지 않아요.
# https://www.skysports.com/football/fehervar-fc-vs-zeta-golubovci/teams/409192
SPORTMONKS_LINEUP_STAT_OVERRIDES = {

    # 2025-semantic 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025-semantic_completion 자료에 있어요.
    14671852288: {79: 2},
    14671853178: {79: 1},
    14671658437: {79: 0},
    14671658440: {52: 0},

    # 2017 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2017_completion 자료에 있어요.
    4581014: {119: 44, 88: 1},

    # 2025 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025_completion 자료에 있어요.
    14670349919: {119: 82},
    14670350042: {119: 19},
    14671656008: {119: 74},
    14671656032: {119: 74},

    # 2024 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2024_completion 자료에 있어요.
    14174750787: {119: 5},

    # 2023 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2023_completion 자료에 있어요.
    4099531969: {84: 1},
    5736304288: {84: 1},
    5317543729: {119: 73, 88: 10},
    5736304269: {119: 77, 88: 2},
    5732404495: {119: 5, 88: 2},

    # 2022 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022_completion 자료에 있어요.
    867462094: {84: 1},
    6259787052: {88: 1, 119: 54},
    6259778404: {88: 4, 119: 62},
    6259776782: {119: 71},
    996187170: {88: 2, 119: 80},
    993425863: {88: 2, 119: 75},
    6259738017: {88: 1, 119: 46},
    993409362: {119: 0},
    6259749338: {119: 41},
    990822056: {88: 1, 119: 79},
    6259749091: {119: 0},
    990511997: {119: 63},
    6259653883: {88: 0, 119: 45},

    # 2021 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2021_completion 자료에 있어요.
    1183422: {119: 46, 88: 4},
    1054373: {119: 0},
    1046145: {84: 0},

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    6265060853: {119: 61},
    6265062320: {119: 29, 84: 0},

    # 2020 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2020_completion 자료에 있어요.
    9451635: {119: 31},
    9547380: {119: 68},

    # 경기 전 부상인 Palombi 대신 선발 출전한 Torromino는 72분에 교체됐어요.
    6402566897: {119: 72},
    # Méndez는 실제 90분에 Max와 교체됐어요. 기존 120분만 고치고 평점·지원 통계는 유지해요.
    # 근거: 20260921-2025-sant-andreu-verified-repairs.json. 미제공 교체 이벤트는 만들지 않아요.
    14671673460: {119: 90},
    # LaLiga와 기존 교체 행의 Neto/Mendoza는 95분이에요. Mendoza의 잘못된 120분만 바로잡아요.
    # 근거: 20260921-2025-quintanar-verified-repairs.json. 평점·지원 통계와 Neto의 25분은 유지해요.
    14671668419: {119: 95},
    # Paks–Cluj의 Tóth·Nkololo는 실제 73분 교체예요. 잘못된 90분만 바로잡아요.
    # Sky 경기표와 기존 교체 시각은 73분이며, 구단 기사의 74분 차이는 별도로 보존했어요.
    # https://www.skysports.com/football/paksi-se-vs-cfr-cluj-napoca/teams/540879
    14670287709: {119: 73},
    14670287687: {119: 73},
    # 2022년 7~8월 해당 경기 교체 기록으로 기존 90분 값만 바로잡아요.
    10517984: {119: 63},
    6260413124: {119: 63},
    10522084: {119: 60},
    6260817214: {119: 76},
    196366601: {119: 68},
    # 교체·퇴장으로 확인한 기존 출전 시간만 바꿔요. 없는 상세는 만들지 않아요.
    10465179: {119: 74},
    6260862840: {119: 81},
    6260862842: {119: 62},
    6260862838: {119: 73},
    6260862609: {119: 49},
    10493249: {119: 45},
    6260824719: {119: 64},
    10493694: {119: 59},
    # St Josephs의 Bauti·Caballero·Boro·Ferrer는 각각 85·57·77·57분에 교체됐어요.
    10437871: {119: 85},
    6260859479: {119: 57},
    6260859481: {119: 77},
    6260858779: {119: 57},
    # Firmino는 1차전 70분, 2차전 75분에 나갔어요. 복사된 90분만 바꿔요.
    10442022: {119: 70},
    10464950: {119: 75},
    # 연장전이어도 Morales는 73분에 교체됐어요. 잘못 복사된 120분을 바로잡아요.
    6260860120: {119: 73},
    6265467104: {119: 75},
    # Ivan은 연장 후반 시작에 투입돼 15분 뛰었어요. Vladislav의 94분이 복사됐어요.
    444323: {119: 15},
}


# 공식 기록·공급자 해설로 중복을 확인한 이벤트 ID만 제외해요.
SPORTMONKS_DUPLICATE_EVENT_IDS = {

    # 2025 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2025_completion 자료에 있어요.
    152787826,

    # 2024 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2024_completion 자료에 있어요.
    156516224,
    156516244,

    # 2023 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2023_completion 자료에 있어요.
    89051453,
    93380844,

    # 2022 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2022_completion 자료에 있어요.
    64240486,
    64241384,

    # 2021 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2021_completion 자료에 있어요.
    87833940,

    # 2019 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2019_completion 자료에 있어요.
    88013534,

    # 2020 경기표와 선수 신원을 대조했어요. 근거는 sportmonks_2020_completion 자료에 있어요.
    88042823,
    # 같은 경기의 실제 78분 퇴장 106909029는 유지하고, 선수 ID 없는 중복 행만 제외해요.
    106909066,
    # Marković는 85분 투입 뒤 88분에 한 번 경고받았어요. 실제 31938036과 경고 상세는 유지해요.
    # 빈 벤치 복제만 제외해요. 근거: 20260921-2017-zelj-first-verified-repairs.json.
    87098039,
    # UEFA 전체 중계·최종 경기표의 늦은 Pêpê 경고는 한 건이에요. 이름 있는 151034671은 유지해요.
    # 빈 90+9분 복제만 제외해요. 근거: 20260921-2025-pafos-cards-verified-repairs.json.
    151034672,
    # City 전체 중계의 Guardiola 54분 경고는 156160516에 있어요. Newcastle 78분 복제만 제외해요.
    # 별개인 Kolo Touré 44분 경고는 원문에 없어요. 근거: 20260921-2025-newcastle-coach-verified-repairs.json.
    156160697,
    # Kairat 67분 Satpaev 경고에 잘못 복제된 상대 Weiss 감독 행만 제외해요.
    # 실제 감독의 90+2분 두 카드는 유지해요. 근거: 20260921-2025-weiss-verified-repairs.json.
    150838859,
    # LaLiga 전체 카드 기록의 Yuri 90+4 경고는 기존 152510566 한 건이에요. 같은 시각의 잘못된 벤치 복제만 제외해요.
    # 근거: 20260921-2025-yuri-verified-repairs.json. 실제 17번의 61분·경고 상세는 유지해요.
    152510573,
    # Chelsea 공식 경기표의 Arteta 경고는 Arsenal의 기존 152680888 한 건이에요.
    # Delap의 팀·분을 복사한 행만 제외해요. 근거: 20260921-2025-arteta-verified-repairs.json.
    152681014,
    # 실제 경기표와 대조했어요. 기존 감독 경고와 실제 선수 경고는 각각 남겨요.
    # 근거: 20260921-2025-roma-fiorentina-brighton-verified-repairs.json.
    156058340,  # Fiorentina–Jagiellonia: Vanoli 111분은 156116437이에요.
    156280259,  # Roma–Bologna: Gasperini 87분은 156280277이에요. Italiano는 별도 보정해요.
    152501731,  # United–Brighton: Hürzeler의 기존 79분 152501924는 유지해요.
    # UEFA 경기표의 실제 감독 경고는 coach_id 행에 이미 있어요.
    # 선수 경고의 팀·분을 복사한 가짜 감독 행만 제외해요. 실제 경고와 선수 기록은 유지해요.
    # 근거: 20260921-2025-five-coach-duplicate-verified-repairs.json.
    152218989,  # Arsenal–Bayern: Arteta 43분은 152218657이에요.
    152219253,  # 같은 경기 Kompany 59분은 152218997이에요.
    152219233,  # Atlético–Inter: Simeone 64분은 152219063이에요.
    152218128,  # Pafos–Monaco: Carcedo 55분은 152218125예요.
    152214555,  # Slavia–Athletic: Trpišovský 42분은 152213857이에요.
    156267925,  # City–Real: Guardiola 25분은 156266610이에요.
    # 같은 UEFA 공식 경기표 대조: 20260921-2025-three-coach-duplicate-verified-repairs.json.
    152339954,  # Nice–Braga: Haise 90+6분은 152339972예요.
    156274588,  # Tottenham–Atlético: Tudor 48분은 156337509예요.
    152810693,  # Lille–Crvena: Stanković 37분은 152810173이에요.
    # Dortmund전 Marlon Gomes의 58분 경고는 한 번이에요. 실제 선발의 148895413만 남겨요.
    # https://shakhtar.com/en/matchday/317817C132E74DAA85EFD5C51785F2CE/line-up
    148896233,
    # AEK–LASK(19873642): Nikolić 감독 경고는 AEK의 11분(157832802)이에요.
    # LASK·80분으로 복제된 행만 제외하고 Andrade의 실제 80분 경고는 남겨요.
    # https://www.laliga.com/en-ES/match/temporada-2026-2027-champions-league-aek-atenas-lask-1
    157833589,
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


# 단건 적재와 라이브 적재가 같은 경기 상세 항목을 요청해요.
FIXTURE_DETAILS_INCLUDE = (
    "events.type;statistics.type;lineups.details;"
    "lineups.player;formations;coaches;pressure"
)
LIVE_FIXTURE_INCLUDE = f"participants;state;scores;periods;{FIXTURE_DETAILS_INCLUDE}"


# 2017년 감독·포메이션과 당시 공식 명단은 옛 구단을 가리켜요.
# 일부 컬렉션에 섞인 재창단 구단 ID만 해당 경기 안에서 정정해요.
SPORTMONKS_FIXTURE_TEAM_ID_OVERRIDES = {
    5512548: {259014: 10728},
    5688046: {258953: 10824},
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

    def get_player_or_none(self, player_id: int, *, include: Optional[str] = None) -> Optional[Dict]:
        response = self._get(f"players/{player_id}", params={"include": include} if include else None)
        # 스쿼드·이적에는 남아 있어도 선수 단건은 조회 불가인 ID(73643·43393)가 있어요.
        # 포함 관계가 달라도 같은 응답이에요. 정상 조회의 빈 목록과 구분해 None을 반환해요.
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

    def get_player_current_teams(self, player_id: int) -> Optional[List[Dict]]:
        # teams는 과거 소속 전체가 아니라 현재 소속이에요. 국가대표도 함께 반환해요.
        player = self.get_player_or_none(player_id, include="teams.team")
        return player["teams"] if player is not None else None

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
            params={"include": FIXTURE_DETAILS_INCLUDE},
        )
        return self.correct_fixture_details(response["data"])

    def get_fixture_details_batch(self, fixture_ids: List[int]) -> List[Dict]:
        """같은 상세 응답을 한 번에 최대 50경기씩 가져와요."""
        return [self.correct_fixture_details(fixture) for fixture in
                self.get_fixtures_batch(fixture_ids, include=FIXTURE_DETAILS_INCLUDE)]

    def get_fixtures_batch(self, fixture_ids: List[int], *, include: str) -> List[Dict]:
        """경기 상태·상세·결장 조회에 같은 ID 검증과 응답 순서를 사용해요."""
        if not 1 <= len(fixture_ids) <= 50:
            raise ValueError("Fixture details batch requires 1 to 50 fixture IDs")
        payloads = self._get(
            "fixtures/multi/" + ",".join(map(str, fixture_ids)),
            params={"include": include},
        )["data"]
        if sorted(f["id"] for f in payloads) != sorted(fixture_ids):
            raise ValueError("Fixture details batch response IDs differ from requested IDs")
        by_id = {f["id"]: f for f in payloads}
        return [by_id[fixture_id] for fixture_id in fixture_ids]

    def get_livescores(self) -> List[Dict]:
        # 실제 응답에는 pagination이 없어요. 경기 시작 전·종료 후 15분도 포함해요.
        return self._get("livescores", params={"include": LIVE_FIXTURE_INCLUDE})["data"]

    def get_live_fixture(self, fixture_id: int) -> Dict:
        return self._get(
            f"fixtures/{fixture_id}", params={"include": LIVE_FIXTURE_INCLUDE},
        )["data"]

    def correct_fixture_details(self, fixture: Dict) -> Dict:
        # 라이브에서도 기존에 검증한 선수·이벤트 ID 보정만 공유해요.
        self._correct_fixture_teams(fixture)
        coach_actors = {
            (coach.get("player_id", coach["id"]), coach["meta"]["participant_id"])
            for coach in fixture.get("coaches", [])
        }
        lineup_actors = {(row["player_id"], row["team_id"]) for row in fixture["lineups"]}
        fixture["events"] = [
            event for event in fixture["events"] if event["id"] not in SPORTMONKS_DUPLICATE_EVENT_IDS
        ]
        for event in fixture["events"]:
            correction = SPORTMONKS_EVENT_OVERRIDES.get(event["id"])
            if correction is not None:
                event.update(correction)
            actor = (event["player_id"], event["participant_id"])
            # Bordalás·Ingolitsch 경고처럼 감독 ID가 선수 칸에 올 수 있어요.
            # 이 경기의 같은 팀 감독으로 확인될 때만 선수 연결을 비우고 경고는 남겨요.
            if (actor in coach_actors and actor not in lineup_actors
                    and event["type"]["code"] in ("yellowcard", "redcard", "yellowred")):
                event["player_id"] = None
            player_ids = SPORTMONKS_EVENT_PLAYER_PROFILE_IDS.get(event["id"])
            if player_ids is not None:
                # 이벤트 선수 전체를 자동 추가하면 잘못 연결된 선수·감독까지 저장돼요.
                event["verified_player_profiles"] = [self._get(f"players/{player_id}")["data"] for player_id in player_ids]
        return self._correct_lineup_players(fixture)

    @staticmethod
    def _correct_fixture_teams(fixture: Dict) -> None:
        mapping = SPORTMONKS_FIXTURE_TEAM_ID_OVERRIDES.get(fixture["id"], {})
        if not mapping:
            return
        for participant in fixture.get("participants", []):
            participant["id"] = mapping.get(participant["id"], participant["id"])
        for key in ("scores", "events", "statistics", "formations", "pressure"):
            for row in fixture.get(key, []):
                row["participant_id"] = mapping.get(row["participant_id"], row["participant_id"])
        for lineup in fixture["lineups"]:
            lineup["team_id"] = mapping.get(lineup["team_id"], lineup["team_id"])
            for detail in lineup["details"]:
                detail["team_id"] = mapping.get(detail["team_id"], detail["team_id"])
        for coach in fixture.get("coaches", []):
            meta = coach["meta"]
            meta["participant_id"] = mapping.get(meta["participant_id"], meta["participant_id"])

    def _correct_lineup_players(self, fixture: Dict) -> Dict:
        fixture["lineups"] = [
            lineup for lineup in fixture["lineups"]
            if lineup["id"] not in SPORTMONKS_DUPLICATE_LINEUP_IDS
        ]
        for lineup in fixture["lineups"]:
            # 출전 시간과 경고 수는 확인한 기존 상세 값만 바꿔요. 미제공 통계는 만들지 않아요.
            stats = SPORTMONKS_LINEUP_STAT_OVERRIDES.get(lineup["id"], {})
            for detail in lineup["details"]:
                if detail["type_id"] in stats:
                    detail["data"]["value"] = stats[detail["type_id"]]
            lineup.update(SPORTMONKS_LINEUP_FIELD_OVERRIDES.get(lineup["id"], {}))
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

    def _iter_transfers(self, path: str, params: dict) -> Iterable[Dict]:
        # 스쿼드 계산과 이적 적재가 같은 원문 보정을 사용하도록 조회 경로를 모아요.
        for item in self._iter_paginated_data(path, params=params):
            if item["id"] not in SPORTMONKS_DUPLICATE_TRANSFER_IDS:
                if item["id"] in TRANSFER_DATE_OVERRIDES:
                    # 확인된 이탈일만 정정해요. 응답 원본과 별도로 제공된 계약 날짜는 바꾸지 않아요.
                    item = {**item, "date": TRANSFER_DATE_OVERRIDES[item["id"]]}
                yield item

    def iter_transfers_by_team(
        self,
        team_id: int,
        per_page: int = 50,
    ) -> Iterable[Dict]:
        return self._iter_transfers(
            f"transfers/teams/{team_id}",
            params={
                "per_page": per_page,
                "include": "player;fromTeam;toTeam;type",
            },
        )

    def iter_transfers_by_player(self, player_id: int) -> Iterable[Dict]:
        # Club History는 경기 화면의 2017/2018 시작점보다 오래된 소속도 필요해요.
        return self._iter_transfers(
            f"transfers/players/{player_id}",
            params={"include": "player;fromTeam;toTeam;type", "per_page": 50},
        )

    def iter_transfers_between_dates(
        self,
        start_date: date,
        end_date: date,
    ):
        return self._iter_transfers(
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
