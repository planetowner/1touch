"""공식 발표·원문 대조로 확인한 이적 ID와 표시 보류 범위예요."""

# 전체 근거와 날짜의 의미는 TRANSFERS_SOURCE_REVIEW.md에 정리했어요.
DUPLICATE_TRANSFER_IDS = {
    # Griezmann: 2026-09-09 사용자가 579015(7/13)를 선택했어요. 공식 발표로 확정한 날짜는 아니에요.
    560549,
    # 현재 계약의 연결 ID·시작일과 공식 공지를 함께 대조한 네 선수예요.
    # Pedraza → 576451: https://prod.sslazio.it/en/news/comunicati/alfonso-pedraza-sag-in-biancoceleste-a-titolo-definitivo
    560566,
    # Touré → 591362: https://www.acmonza.com/en/news/idrissa-toure-joins-ac-monza/
    591097,
    # Namaso → 576087: https://www.aja.fr/danny-namaso-officiellement-transfere-a-laja/
    563438,
    # Falcone → 233266: https://www.uslecce.it/news/40900136454/wladimiro-falcone-e-un-calciatore-del-lecce
    225557,
    # Kerkez → 232335(2023-07-20). AZ의 이적 발표와 당시 보도가 일치해요.
    # https://www.az.nl/inside-az/nieuws/2023/juli/kerkez-verruilt-az-voor-afc-bournemouth
    232198,
    # Costinha → 365085(2024-07-09). 실제 영입 발표가 없는 7/1 행을 제외해요.
    # https://www.olympiacos.org/en/2024/07/09/costinha-joins-olympiacos/
    296082,
    # Pierotti → 240671(2024-01-16). 1/13은 메디컬 전 보도이며 계약 시작도 1/16이에요.
    # https://uslecce.it/pierotti-in-giallorosso/
    240514,
    # Huijsen → 354980(2023-11-07). 구단이 이날부터 공식 1군이라고 명시했어요.
    # https://www.juventus.com/en/news/articles/huijsen-and-yildiz-added-to-the-juventus-first-team
    235198,
    # Pedro Felipe → 586791(2026-08-04). 7/31 공지는 철회됐고 계약 시작도 8/4예요.
    # https://www.juventus.com/it/news/articoli/next-gen-pedro-felipe-a-titolo-definitivo-al-racing-santander
    585153,
    # Wei → 578256(2026-07-09). 구단의 영입 발표와 제공된 계약 시작이 일치해요.
    # https://www.aja.fr/grand-espoir-chinois-xiangxin-wei-signe-a-laja/
    566271,
    # Friedrich → 478531. 원래 24/25 후반부터 25/26 말까지 18개월 임대여서 7/1에 새로 간 것이 아니에요.
    # https://www.fc-union-berlin.de/de/meldungen/union-verlaengert-mit-julien-friedrich-5sQ8uy
    461051,
    # Esposito 형제 → 479987·483363(2025-06-10). Datasport의 실제 소속 시작과 6/11 Inter 명단을 대조했어요.
    # https://www.datasport.it/calcio/calciatori/Esposito-Sebastiano-16864.html
    # https://www.datasport.it/calcio/calciatori/Esposito-Francesco-pio-39673.html
    # https://www.inter.it/en/news/squad-inter-world-club-2025
    441645, 354403,
    # Salah → 587251(2026-08-05). 8/4는 협상·입국 예고이고 8/5 영입 공지와 계약 시작이 일치해요.
    # https://www.trabzonspor.org.tr/tr/haberler/yeni-transferimiz-mohamed-salahin-ilk-sozleri-05-08-2026
    586782,
    # Kolodziejczak·Riou·Lopez는 25/26에도 Paris FC에 있었어요. 재계약 뒤 남은 2025년 이탈을 제외해요.
    # https://parisfc.fr/pfc_joueurs/timothee-kolodziejczak/
    # https://parisfc.fr/equipe-pro/remy-riou-prolonge-avec-le-paris-fc-jusquen-2026/
    # https://www.lequipe.fr/Football/Actualites/Figure-emblematique-du-paris-fc-julien-lopez-renforce-l-as-cannes-promu-en-ligue-3/1686436
    489635, 489638, 489633,
    # Hanin·Sangalli도 2026년까지 재계약했어요. 제공된 2026년 이탈 행을 유지해요.
    # https://angers-sco.fr/florent-hanin-prolonge-avec-angers-sco-2/
    # https://www.realracingclub.es/noticias/el-racing-renueva-a-marco-sangalli-hasta-el-30-de-junio-de-2026
    489634, 489824,
    # Barák → 597171(2026-09-04). 7월 협상은 결렬됐고 9월에 다시 영입했어요.
    # https://www.alphanews.live/sports/episimo-antonin-barak-xana-ston-apoel/
    581933,
    # Fulgini·Coba → 578073·578112(2026-07-09). 영입 확정과 계약 시작 7/22는 다른 날짜예요.
    # https://www.lensois.com/le-rc-lens-officialise-le-depart-dangelo-fulgini-qui-sengage-avec-al-khaleej/
    # https://as.com/futbol/primera/oficial-coba-jugara-en-arabia-saudi-f202607-n/
    581706, 581707,
    # Mata의 실제 계약 해지는 2025-12-21이에요. 7월 이탈을 제외하고 아래에서 남은 행의 날짜를 정정해요.
    475796,
    # Coulibaly → 481161(2025-06-05). 구단이 조기 복귀를 확인해 기존 6/30 예정 행을 제외해요.
    # https://www.bvb.de/de/de/aktuelles/news/news.html/2025/6/5/Coulibaly-vorzeitig-nach-Dortmund-zurueckgekehrt.html
    446715,
    # Dellavalle → 507405(2026-06-30). 만료 전 임대가 1년 연장돼 2025년 복귀는 발생하지 않았어요.
    # https://modenacalcio.com/calciomercato-dellavalle-sara-ancora-gialloblu/
    456789,
    # Cuenca → 580583(2026-07-17). Como 발표와 EFE의 당일 합류 보도를 대조했어요.
    # https://comofootball.com/en/como-1907-sign-uefa-under-19-european-champion-andres-cuenca/
    # https://proceso.hn/el-como-ficha-al-defensa-espanol-andres-cuenca-procedente-del-barcelona/
    562576,
}

# Mata는 두 원문 날짜가 모두 틀렸어요. 당일 구단 발표를 인용한 두 보도가 같은 해지일을 확인해요.
# https://as.com/futbol/segunda/la-ud-las-palmas-rescinde-el-contrato-de-jaime-mata-f202512-n/
# https://www.estadiodeportivo.com/futbol/las-palmas/las-palmas-rescinde-contrato-jaime-mata-futbolista-libre-para-firmar-por-cualquier-club-20251221-524421.html
TRANSFER_DATE_OVERRIDES = {538587: "2025-12-21"}

# 웹 대조로도 확정하지 못한 이력은 사용자가 정한 기준에 따라 이적 화면만 보류해요.
# 두 행이 모두 실제 재임대일 수도 있어요. 원문·현재 계약은 보존하고 확인 뒤 이 목록에서 해제해요.
# 처음 보는 충돌까지 무시하지 않도록 확인한 선수와 이적 ID 쌍만 기록해요.
WITHHELD_PLAYER_MOVEMENTS = {
    37317392: (348853, 446304),  # Xavi Simons: 24/25 재임대 행이 빠져 있어요.
    37316834: (446227, 391608),  # Harvey Davies: 1군 훈련·U21 출전으로 공식 승격일을 정할 수 없어요.
    37562129: (352515, 452628),  # Andrey Santos: 2024년 재임대 행과 정확한 소속 구간이 빠져 있어요.
    37736024: (386049, 511181),  # Nathan De Cat: 9/27은 재계약·1군 훈련 합류 공지예요.
    37337155: (282949, 446764),  # Patouillet: 재임대는 확인했지만 6/22 발표와 실제 시작을 구분해야 해요.
    32387131: (538682, 592402),  # Wahi: 두 임대는 실제이고 중간 복귀 날짜는 자료가 충분하지 않아요.
    133957: (424581, 492161),    # Pellegri: 2025년 재임대 행이 빠져 두 복귀를 연결할 수 없어요.
    1477610: (270621, 436310),   # Antov: 서로 다른 시즌의 임대 복귀이며 재임대 행이 빠져 있어요.
    37608596: (543935, 578992),  # Fini: 임대 연장·재임대 표기가 달라 중간 이탈을 확정하지 않아요.
    37593154: (483305, 455883),  # Veiga: 6/10 복귀 자료와 6/30 계약 종료 자료를 구분할 근거가 부족해요.
    # 2026-09-10 최근 시장 추가 점검. 선수별 근거·URL은 TRANSFERS_SOURCE_REVIEW.md에 있어요.
    6301: (546229, 593283),      # Fofana: 두 임대가 실제이며 여름 복귀 행·날짜가 빠져 있어요.
    21762805: (566388, 596511),  # Morro: 9/2 보도는 월요일 밤 해지를 설명해 원문 이탈일과 일치하지 않아요.
    32796892: (234009, 306912),  # Carstensen: 9/25는 재계약·전업 전환이며 이미 1군에 출전했어요.
    37396570: (284044, 241727),  # Sosa: 1/15 영입은 확인했지만 이후 Santa Fe·Colo-Colo 임대 구간도 충돌해요.
    37550477: (539711, 595957),  # Humphreys: 두 차례 임대 사이의 정확한 복귀일이 제공되지 않았어요.
    37599469: (515144, 595424),  # Missori: 두 시즌 임대가 실제이며 중간 복귀 행이 빠져 있어요.
    37644894: (520473, 497825),  # Frees: 8/14는 재계약·1군 육성 계획이며 정식 승격일을 확인하지 못했어요.
    37720269: (545669, 576280),  # Dixon: 7/2는 임대 연장이며 현재 계약도 이 행을 참조해 임의로 삭제하지 않아요.
}
