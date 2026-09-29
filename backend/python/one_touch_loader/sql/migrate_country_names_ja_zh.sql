-- 기존 국가 행에만 일본어·중국어 간체 이름을 붙이고, 한국어·원문 이름·참조 ID는 유지해요.
-- teams·competitions의 name_ja/name_zh 규칙과 countries.name_ko의 길이·정렬 규칙을 따라요.
ALTER TABLE countries
  ADD COLUMN name_ja VARCHAR(120)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  ADD COLUMN name_zh VARCHAR(120)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL;

-- EA 공식 FC 국가명, 2026-09-29 UTC 확인:
-- https://drop-api.ea.com/rating/ea-sports-fc/filters?locale=en
-- https://drop-api.ea.com/rating/ea-sports-fc/filters?locale=ja
-- https://drop-api.ea.com/rating/ea-sports-fc/filters?locale=zh-hans
-- https://www.ea.com/ja/games/ea-sports-fc/ratings 의 ratingsFilters.nationality
-- API의 중복 Comoros(EA 214)는 같은 ID의 번역된 항목을 사용해요.
-- 일본어 웹 목록에만 있는 9개 국가는 name_ja만 채워요. 번체를 간체로 바꾸지 않아요.
-- 기존 238개 중 일본어 166개·간체 157개를 매핑하고, 출처에 없는 이름은 NULL로 남겨요.
-- 행 끝의 EA ID와 원문은 출처를 다시 대조하기 위한 정보이며 DB의 국가 ID가 아니에요.
START TRANSACTION;

UPDATE countries AS c
JOIN (
  SELECT 2 AS country_id, 'ポーランド' AS name_ja, '波兰' AS name_zh -- EA 37: Poland
  UNION ALL SELECT 5, 'ブラジル', '巴西' -- EA 54: Brazil
  UNION ALL SELECT 11, 'ドイツ', '德国' -- EA 21: Germany
  UNION ALL SELECT 17, 'フランス', '法国' -- EA 18: France
  UNION ALL SELECT 20, 'ポルトガル', '葡萄牙' -- EA 38: Portugal
  UNION ALL SELECT 23, 'コートジボワール', '科特迪瓦' -- EA 108: Côte d'Ivoire -> Ivory Coast
  UNION ALL SELECT 26, 'マリ', '马里' -- EA 126: Mali
  UNION ALL SELECT 32, 'スペイン', '西班牙' -- EA 45: Spain
  UNION ALL SELECT 38, 'オランダ', '荷兰' -- EA 34: Holland -> Netherlands
  UNION ALL SELECT 44, 'アルゼンチン', '阿根廷' -- EA 52: Argentina
  UNION ALL SELECT 47, 'スウェーデン', '瑞典' -- EA 46: Sweden
  UNION ALL SELECT 62, 'スイス', '瑞士' -- EA 47: Switzerland
  UNION ALL SELECT 80, 'チリ', '智利' -- EA 55: Chile
  UNION ALL SELECT 86, 'ウクライナ', '乌克兰' -- EA 49: Ukraine
  UNION ALL SELECT 98, 'オーストラリア', '澳大利亚' -- EA 195: Australia
  UNION ALL SELECT 107, 'イラク', '伊拉克' -- EA 162: Iraq
  UNION ALL SELECT 116, 'キプロス', '塞浦路斯' -- EA 11: Cyprus
  UNION ALL SELECT 119, 'ジョージア', '格鲁吉亚' -- EA 20: Georgia
  UNION ALL SELECT 122, 'コソボ', '科索沃' -- EA 219: Kosovo
  UNION ALL SELECT 125, 'ギリシャ', '希腊' -- EA 22: Greece
  UNION ALL SELECT 143, 'オーストリア', '奥地利' -- EA 4: Austria
  UNION ALL SELECT 146, '南アフリカ', '南非' -- EA 140: South Africa
  UNION ALL SELECT 155, 'ルーマニア', '罗马尼亚' -- EA 39: Romania
  UNION ALL SELECT 158, 'ウルグアイ', '乌拉圭' -- EA 60: Uruguay
  UNION ALL SELECT 200, 'セネガル', '塞内加尔' -- EA 136: Senegal
  UNION ALL SELECT 212, 'ベラルーシ', '白俄罗斯' -- EA 6: Belarus
  UNION ALL SELECT 224, 'ブルガリア', '保加利亚' -- EA 9: Bulgaria
  UNION ALL SELECT 227, 'ロシア', '俄罗斯' -- EA 40: Russia
  UNION ALL SELECT 245, 'チェコ', '捷克共和国' -- EA 12: Czech Republic
  UNION ALL SELECT 251, 'イタリア', '意大利' -- EA 27: Italy
  UNION ALL SELECT 266, 'クロアチア', '克罗地亚' -- EA 10: Croatia
  UNION ALL SELECT 275, 'ベネズエラ', '委内瑞拉' -- EA 61: Venezuela
  UNION ALL SELECT 296, 'セルビア', '塞尔维亚' -- EA 51: Serbia
  UNION ALL SELECT 311, 'ニューカレドニア', NULL -- EA 215: New Caledonia
  UNION ALL SELECT 320, 'デンマーク', '丹麦' -- EA 13: Denmark
  UNION ALL SELECT 338, 'ペルー', '秘鲁' -- EA 59: Peru
  UNION ALL SELECT 353, 'コロンビア', '哥伦比亚' -- EA 56: Colombia
  UNION ALL SELECT 401, 'スロバキア', '斯洛伐克' -- EA 43: Slovakia
  UNION ALL SELECT 404, 'トルコ', '土耳其' -- EA 48: Turkey -> Türkiye
  UNION ALL SELECT 455, 'アイルランド', '爱尔兰共和国' -- EA 25: Republic of Ireland
  UNION ALL SELECT 458, 'メキシコ', '墨西哥' -- EA 83: Mexico
  UNION ALL SELECT 459, 'エクアドル', '厄瓜多尔' -- EA 57: Ecuador
  UNION ALL SELECT 462, 'イングランド', '英格兰' -- EA 14: England
  UNION ALL SELECT 468, 'ガーナ', '加纳' -- EA 117: Ghana
  UNION ALL SELECT 479, '日本', '日本' -- EA 163: Japan
  UNION ALL SELECT 488, 'イラン', '伊朗' -- EA 161: Iran
  UNION ALL SELECT 491, '北アイルランド', '北爱尔兰' -- EA 35: Northern Ireland
  UNION ALL SELECT 507, 'ボスニア・ヘルツェゴビナ', '波斯尼亚和黑塞哥维那' -- EA 8: Bosnia and Herzegovina
  UNION ALL SELECT 515, 'ウェールズ', '威尔士' -- EA 50: Wales
  UNION ALL SELECT 556, 'ベルギー', '比利时' -- EA 7: Belgium
  UNION ALL SELECT 593, 'カメルーン', '喀麦隆' -- EA 103: Cameroon
  UNION ALL SELECT 607, 'ブルキナファソ', '布基纳法索' -- EA 101: Burkina Faso
  UNION ALL SELECT 614, 'アルジェリア', '阿尔及利亚' -- EA 97: Algeria
  UNION ALL SELECT 674, 'ハンガリー', '匈牙利' -- EA 23: Hungary
  UNION ALL SELECT 712, '韓国', '韩国' -- EA 167: Korea Republic -> South Korea
  UNION ALL SELECT 716, 'ナイジェリア', '尼日利亚' -- EA 133: Nigeria
  UNION ALL SELECT 719, 'リベリア', '利比里亚' -- EA 122: Liberia
  UNION ALL SELECT 748, 'ラトビア', '拉脱维亚' -- EA 28: Latvia
  UNION ALL SELECT 772, 'カーボベルデ', '佛得角群岛' -- EA 104: Cape Verde Islands -> Cape Verde
  UNION ALL SELECT 802, 'イスラエル', '以色列' -- EA 26: Israel
  UNION ALL SELECT 821, 'ブルンジ', '布隆迪' -- EA 102: Burundi
  UNION ALL SELECT 886, 'エジプト', '埃及' -- EA 111: Egypt
  UNION ALL SELECT 911, 'アンゴラ', '安哥拉' -- EA 98: Angola
  UNION ALL SELECT 919, 'アルメニア', '亚美尼亚' -- EA 3: Armenia
  UNION ALL SELECT 998, 'モンテネグロ', '黑山共和国' -- EA 15: Montenegro
  UNION ALL SELECT 1004, 'カナダ', '加拿大' -- EA 70: Canada
  UNION ALL SELECT 1161, 'スコットランド', '苏格兰' -- EA 42: Scotland
  UNION ALL SELECT 1176, 'ホンジュラス', '洪都拉斯' -- EA 81: Honduras
  UNION ALL SELECT 1179, 'ケニア', '肯尼亚' -- EA 120: Kenya
  UNION ALL SELECT 1190, 'パラグアイ', '巴拉圭' -- EA 58: Paraguay
  UNION ALL SELECT 1233, 'フィンランド', '芬兰' -- EA 17: Finland
  UNION ALL SELECT 1247, '中央アフリカ共和国', '中非共和国' -- EA 105: Central African Republic
  UNION ALL SELECT 1320, 'コンゴ民主共和国', '刚果民主共和国' -- EA 110: Congo DR -> DR Congo
  UNION ALL SELECT 1424, 'モロッコ', '摩洛哥' -- EA 129: Morocco
  UNION ALL SELECT 1439, 'チュニジア', '突尼斯' -- EA 145: Tunisia
  UNION ALL SELECT 1560, 'コンゴ', '刚果共和国' -- EA 107: Congo -> Republic of the Congo
  UNION ALL SELECT 1578, 'ノルウェー', '挪威' -- EA 36: Norway
  UNION ALL SELECT 1638, 'スロベニア', '斯洛文尼亚' -- EA 44: Slovenia
  UNION ALL SELECT 1640, 'ジャマイカ', '牙买加' -- EA 82: Jamaica
  UNION ALL SELECT 1646, 'マダガスカル', '马达加斯加' -- EA 124: Madagascar
  UNION ALL SELECT 1703, 'ギニア', '几内亚' -- EA 118: Guinea
  UNION ALL SELECT 1707, 'ギニアビサウ', '几内亚比绍' -- EA 119: Guinea-Bissau
  UNION ALL SELECT 1739, 'コスタリカ', '哥斯达黎加' -- EA 72: Costa Rica
  UNION ALL SELECT 1796, 'アイスランド', '冰岛' -- EA 24: Iceland
  UNION ALL SELECT 1985, 'ガイアナ', '圭亚那' -- EA 79: Guyana
  UNION ALL SELECT 2079, 'リトアニア', '立陶宛' -- EA 30: Lithuania
  UNION ALL SELECT 2088, 'スリナム', '苏里南' -- EA 92: Suriname
  UNION ALL SELECT 2154, 'フェロー諸島', '法罗群岛' -- EA 16: Faroe Islands
  UNION ALL SELECT 2177, 'ハイチ', '海地' -- EA 80: Haiti
  UNION ALL SELECT 2228, 'トリニダード・トバゴ', '特立尼达和多巴哥' -- EA 93: Trinidad and Tobago
  UNION ALL SELECT 2325, 'ジンバブエ', '津巴布韦' -- EA 148: Zimbabwe
  UNION ALL SELECT 2345, 'モルドバ', '摩尔多瓦' -- EA 33: Moldova
  UNION ALL SELECT 2405, 'エストニア', '爱沙尼亚' -- EA 208: Estonia
  UNION ALL SELECT 2426, 'ウズベキスタン', '乌兹别克斯坦' -- EA 191: Uzbekistan
  UNION ALL SELECT 2427, 'カザフスタン', NULL -- EA 165: Kazakhstan
  UNION ALL SELECT 2453, 'アゼルバイジャン', '阿塞拜疆' -- EA 5: Azerbaijan
  UNION ALL SELECT 2454, 'アルバニア', '阿尔巴尼亚' -- EA 1: Albania
  UNION ALL SELECT 2493, 'モーリタニア', '毛里塔尼亚' -- EA 127: Mauritania
  UNION ALL SELECT 2507, 'ガンビア', '冈比亚' -- EA 116: Gambia
  UNION ALL SELECT 2568, 'ザンビア', '赞比亚' -- EA 147: Zambia
  UNION ALL SELECT 2756, 'マルタ', '马耳他' -- EA 32: Malta
  UNION ALL SELECT 2802, 'アラブ首長国連邦', '阿联酋' -- EA 190: United Arab Emirates
  UNION ALL SELECT 2817, 'ニュージーランド', '新西兰' -- EA 198: New Zealand
  UNION ALL SELECT 2931, 'アンドラ', '安道尔' -- EA 2: Andorra
  UNION ALL SELECT 3039, 'トーゴ', '多哥' -- EA 144: Togo
  UNION ALL SELECT 3126, 'ルクセンブルク', '卢森堡' -- EA 31: Luxembourg
  UNION ALL SELECT 3374, 'ジブラルタル', '直布罗陀' -- EA 205: Gibraltar
  UNION ALL SELECT 3483, 'アメリカ', '美国' -- EA 95: United States
  UNION ALL SELECT 3662, 'ガボン', '加蓬' -- EA 115: Gabon
  UNION ALL SELECT 3677, 'シリア', '叙利亚' -- EA 186: Syria
  UNION ALL SELECT 3995, 'マレーシア', '马来西亚' -- EA 173: Malaysia
  UNION ALL SELECT 4125, 'ウガンダ', '乌干达' -- EA 146: Uganda
  UNION ALL SELECT 5618, '中国', '中国' -- EA 155: China PR -> China
  UNION ALL SELECT 5724, 'シエラレオネ', '塞拉利昂' -- EA 138: Sierra Leone
  UNION ALL SELECT 5790, 'ナミビア', '纳米比亚' -- EA 131: Namibia
  UNION ALL SELECT 6783, 'モザンビーク', '莫桑比克' -- EA 130: Mozambique
  UNION ALL SELECT 7091, 'オマーン', NULL -- EA 178: Oman
  UNION ALL SELECT 7437, 'キュラソー', '库拉索岛' -- EA 85: Curaçao
  UNION ALL SELECT 7563, 'ソマリア', '索马里' -- EA 139: Somalia
  UNION ALL SELECT 7598, 'ボリビア', '玻利维亚' -- EA 53: Bolivia
  UNION ALL SELECT 7830, 'ベナン', '贝宁' -- EA 99: Benin
  UNION ALL SELECT 12095, 'セントルシア', '圣卢西亚' -- EA 90: St. Lucia -> Saint Lucia
  UNION ALL SELECT 14837, 'モントセラト', '蒙塞拉特岛' -- EA 84: Montserrat
  UNION ALL SELECT 15326, 'バミューダ', '百慕大' -- EA 68: Bermuda
  UNION ALL SELECT 16175, 'リビア', '利比亚' -- EA 123: Libya
  UNION ALL SELECT 20802, 'マラウイ', '马拉维' -- EA 125: Malawi
  UNION ALL SELECT 21795, 'リヒテンシュタイン', '列支敦士登' -- EA 29: Liechtenstein
  UNION ALL SELECT 26833, 'グレナダ', '格林纳达' -- EA 77: Grenada
  UNION ALL SELECT 33497, 'バルバドス', '巴巴多斯' -- EA 66: Barbados
  UNION ALL SELECT 35008, 'エルサルバドル', '萨尔瓦多' -- EA 76: El Salvador
  UNION ALL SELECT 35210, 'タンザニア', '坦桑尼亚' -- EA 143: Tanzania
  UNION ALL SELECT 35376, 'サウジアラビア', '沙特阿拉伯' -- EA 183: Saudi Arabia
  UNION ALL SELECT 38404, 'スリランカ', '斯里兰卡' -- EA 185: Sri Lanka
  UNION ALL SELECT 43321, 'エリトリア', NULL -- EA 113: Eritrea
  UNION ALL SELECT 43444, 'アフガニスタン', '阿富汗' -- EA 149: Afghanistan
  UNION ALL SELECT 45412, 'レバノン', '黎巴嫩' -- EA 171: Lebanon
  UNION ALL SELECT 48946, 'パレスチナ', '巴勒斯坦' -- EA 180: Palestine
  UNION ALL SELECT 49477, 'タイ', '泰国' -- EA 188: Thailand
  UNION ALL SELECT 50809, 'フィリピン', '菲律宾' -- EA 181: Philippines
  UNION ALL SELECT 52126, 'パキスタン', '巴基斯坦' -- EA 179: Pakistan
  UNION ALL SELECT 53128, 'グアテマラ', '危地马拉' -- EA 78: Guatemala
  UNION ALL SELECT 57142, '北マケドニア', '北马其顿' -- EA 19: North Macedonia
  UNION ALL SELECT 57160, 'タジキスタン', '塔吉克斯坦' -- EA 187: Tajikistan
  UNION ALL SELECT 63604, 'キューバ', '古巴' -- EA 73: Cuba
  UNION ALL SELECT 64306, '香港', '中国香港' -- EA 158: Hong Kong
  UNION ALL SELECT 65053, 'ニジェール', '尼日尔' -- EA 132: Niger
  UNION ALL SELECT 65437, 'パナマ', '巴拿马' -- EA 87: Panama
  UNION ALL SELECT 74505, 'カタール', NULL -- EA 182: Qatar
  UNION ALL SELECT 77580, 'プエルトリコ', '波多黎各' -- EA 88: Puerto Rico
  UNION ALL SELECT 79146, 'ドミニカ共和国', '多米尼加共和国' -- EA 207: Dominican Republic
  UNION ALL SELECT 88137, 'ルワンダ', '卢旺达' -- EA 134: Rwanda
  UNION ALL SELECT 88407, 'インドネシア', '印度尼西亚' -- EA 160: Indonesia
  UNION ALL SELECT 97374, 'ヨルダン', '约旦' -- EA 164: Jordan
  UNION ALL SELECT 98799, 'チャド', '乍得' -- EA 106: Chad
  UNION ALL SELECT 137919, 'アンティグア・バーブーダ', '安提瓜和巴布达' -- EA 63: Antigua and Barbuda
  UNION ALL SELECT 153732, 'インド', '印度' -- EA 159: India
  UNION ALL SELECT 155043, 'バングラデッシュ', '孟加拉国' -- EA 151: Bangladesh
  UNION ALL SELECT 160047, 'セントキッツ・ネービス', '圣基茨和尼维斯' -- EA 89: St. Kitts and Nevis -> Saint Kitts and Nevis
  UNION ALL SELECT 179748, 'サントメ・プリンシペ', NULL -- EA 135: São Tomé e Príncipe -> São Tomé and Príncipe
  UNION ALL SELECT 190318, 'イエメン', NULL -- EA 193: Yemen
  UNION ALL SELECT 211975, '赤道ギニア', '赤道几内亚' -- EA 112: Equatorial Guinea
  UNION ALL SELECT 213370, 'チャイニーズタイペイ', '中华台北' -- EA 213: Chinese Taipei -> Taiwan
  UNION ALL SELECT 360931, 'モーリシャス', NULL -- EA 128: Mauritius
  UNION ALL SELECT 364678, 'コモロ', '科摩罗' -- EA 214: Comoros
  UNION ALL SELECT 867012, 'バヌアツ', '瓦努阿图' -- EA 204: Vanuatu
  UNION ALL SELECT 1442002, '北朝鮮', NULL -- EA 166: Korea DPR
) AS names ON names.country_id = c.country_id
SET c.name_ja = names.name_ja,
    c.name_zh = names.name_zh;

COMMIT;

SELECT COUNT(*) AS total_countries,
       COUNT(name_ko) AS korean_names,
       COUNT(name_ja) AS japanese_names,
       COUNT(name_zh) AS simplified_chinese_names
FROM countries;

SELECT country_id, name, name_ko, name_ja, name_zh
FROM countries
ORDER BY country_id;
