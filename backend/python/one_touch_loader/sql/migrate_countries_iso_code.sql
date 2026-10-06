-- 국가에는 ISO 3166-1 alpha-2, 영국 구성국에는 ISO 3166-2 코드를 저장해요.
-- 영국 지역 코드도 담을 수 있도록 최대 6글자를 허용해요.
ALTER TABLE countries
  ADD COLUMN iso_code VARCHAR(6)
    CHARACTER SET ascii COLLATE ascii_bin NULL
    COMMENT 'ISO 3166-1 alpha-2 또는 ISO 3166-2 공식 코드';

-- 2026-10-06에 운영 DB의 국가 ID·이름과 아래 자료를 대조했어요.
-- ISO 표준: https://www.iso.org/iso-3166-country-codes.html
-- 국가 코드 목록: https://www.ripe.net/community/internet-governance/internet-technical-community/the-rir-system/list-of-country-codes-and-rirs/
-- 영국 구성국: https://www.gov.uk/government/publications/open-standards-for-government/country-codes
-- 공급자 ID 대조: https://api.sportmonks.com/v3/core/countries
-- 238개 중 국가 코드 222개·영국 지역 코드 4개를 채우고, 나머지 12개는 NULL로 둬요.
-- 타히티·잔지바르에 상위 지역 코드를 대신 넣거나, 코소보에 비공식 XK를 넣지 않아요.
-- 대륙·World·International·West Indies도 공식 국가·지역 코드가 없어 비워 둬요.
-- 키르기스스탄의 기존 ID 두 개는 같은 KG를 쓰므로 UNIQUE 제약을 추가하지 않아요.
START TRANSACTION;

UPDATE countries AS c
JOIN (
  SELECT 2 AS country_id, 'PL' AS iso_code -- Poland
  UNION ALL SELECT 5, 'BR' -- Brazil
  UNION ALL SELECT 11, 'DE' -- Germany
  UNION ALL SELECT 17, 'FR' -- France
  UNION ALL SELECT 20, 'PT' -- Portugal
  UNION ALL SELECT 23, 'CI' -- Ivory Coast
  UNION ALL SELECT 26, 'ML' -- Mali
  UNION ALL SELECT 32, 'ES' -- Spain
  UNION ALL SELECT 38, 'NL' -- Netherlands
  UNION ALL SELECT 44, 'AR' -- Argentina
  UNION ALL SELECT 47, 'SE' -- Sweden
  UNION ALL SELECT 62, 'CH' -- Switzerland
  UNION ALL SELECT 80, 'CL' -- Chile
  UNION ALL SELECT 86, 'UA' -- Ukraine
  UNION ALL SELECT 98, 'AU' -- Australia
  UNION ALL SELECT 107, 'IQ' -- Iraq
  UNION ALL SELECT 116, 'CY' -- Cyprus
  UNION ALL SELECT 119, 'GE' -- Georgia
  UNION ALL SELECT 125, 'GR' -- Greece
  UNION ALL SELECT 143, 'AT' -- Austria
  UNION ALL SELECT 146, 'ZA' -- South Africa
  UNION ALL SELECT 155, 'RO' -- Romania
  UNION ALL SELECT 158, 'UY' -- Uruguay
  UNION ALL SELECT 200, 'SN' -- Senegal
  UNION ALL SELECT 212, 'BY' -- Belarus
  UNION ALL SELECT 224, 'BG' -- Bulgaria
  UNION ALL SELECT 227, 'RU' -- Russia
  UNION ALL SELECT 245, 'CZ' -- Czech Republic
  UNION ALL SELECT 251, 'IT' -- Italy
  UNION ALL SELECT 266, 'HR' -- Croatia
  UNION ALL SELECT 275, 'VE' -- Venezuela
  UNION ALL SELECT 296, 'RS' -- Serbia
  UNION ALL SELECT 311, 'NC' -- New Caledonia
  UNION ALL SELECT 320, 'DK' -- Denmark
  UNION ALL SELECT 338, 'PE' -- Peru
  UNION ALL SELECT 353, 'CO' -- Colombia
  UNION ALL SELECT 401, 'SK' -- Slovakia
  UNION ALL SELECT 404, 'TR' -- Türkiye
  UNION ALL SELECT 455, 'IE' -- Republic of Ireland
  UNION ALL SELECT 458, 'MX' -- Mexico
  UNION ALL SELECT 459, 'EC' -- Ecuador
  UNION ALL SELECT 462, 'GB-ENG' -- England
  UNION ALL SELECT 468, 'GH' -- Ghana
  UNION ALL SELECT 479, 'JP' -- Japan
  UNION ALL SELECT 488, 'IR' -- Iran
  UNION ALL SELECT 491, 'GB-NIR' -- Northern Ireland
  UNION ALL SELECT 507, 'BA' -- Bosnia and Herzegovina
  UNION ALL SELECT 515, 'GB-WLS' -- Wales
  UNION ALL SELECT 556, 'BE' -- Belgium
  UNION ALL SELECT 593, 'CM' -- Cameroon
  UNION ALL SELECT 607, 'BF' -- Burkina Faso
  UNION ALL SELECT 614, 'DZ' -- Algeria
  UNION ALL SELECT 674, 'HU' -- Hungary
  UNION ALL SELECT 712, 'KR' -- South Korea
  UNION ALL SELECT 716, 'NG' -- Nigeria
  UNION ALL SELECT 719, 'LR' -- Liberia
  UNION ALL SELECT 748, 'LV' -- Latvia
  UNION ALL SELECT 772, 'CV' -- Cape Verde
  UNION ALL SELECT 802, 'IL' -- Israel
  UNION ALL SELECT 821, 'BI' -- Burundi
  UNION ALL SELECT 886, 'EG' -- Egypt
  UNION ALL SELECT 911, 'AO' -- Angola
  UNION ALL SELECT 919, 'AM' -- Armenia
  UNION ALL SELECT 998, 'ME' -- Montenegro
  UNION ALL SELECT 1004, 'CA' -- Canada
  UNION ALL SELECT 1040, 'RE' -- Réunion
  UNION ALL SELECT 1161, 'GB-SCT' -- Scotland
  UNION ALL SELECT 1176, 'HN' -- Honduras
  UNION ALL SELECT 1179, 'KE' -- Kenya
  UNION ALL SELECT 1190, 'PY' -- Paraguay
  UNION ALL SELECT 1233, 'FI' -- Finland
  UNION ALL SELECT 1247, 'CF' -- Central African Republic
  UNION ALL SELECT 1320, 'CD' -- DR Congo
  UNION ALL SELECT 1424, 'MA' -- Morocco
  UNION ALL SELECT 1439, 'TN' -- Tunisia
  UNION ALL SELECT 1560, 'CG' -- Republic of the Congo
  UNION ALL SELECT 1578, 'NO' -- Norway
  UNION ALL SELECT 1638, 'SI' -- Slovenia
  UNION ALL SELECT 1640, 'JM' -- Jamaica
  UNION ALL SELECT 1646, 'MG' -- Madagascar
  UNION ALL SELECT 1703, 'GN' -- Guinea
  UNION ALL SELECT 1707, 'GW' -- Guinea-Bissau
  UNION ALL SELECT 1739, 'CR' -- Costa Rica
  UNION ALL SELECT 1796, 'IS' -- Iceland
  UNION ALL SELECT 1985, 'GY' -- Guyana
  UNION ALL SELECT 2079, 'LT' -- Lithuania
  UNION ALL SELECT 2088, 'SR' -- Suriname
  UNION ALL SELECT 2154, 'FO' -- Faroe Islands
  UNION ALL SELECT 2177, 'HT' -- Haiti
  UNION ALL SELECT 2228, 'TT' -- Trinidad and Tobago
  UNION ALL SELECT 2325, 'ZW' -- Zimbabwe
  UNION ALL SELECT 2345, 'MD' -- Moldova
  UNION ALL SELECT 2405, 'EE' -- Estonia
  UNION ALL SELECT 2426, 'UZ' -- Uzbekistan
  UNION ALL SELECT 2427, 'KZ' -- Kazakhstan
  UNION ALL SELECT 2453, 'AZ' -- Azerbaijan
  UNION ALL SELECT 2454, 'AL' -- Albania
  UNION ALL SELECT 2493, 'MR' -- Mauritania
  UNION ALL SELECT 2507, 'GM' -- Gambia
  UNION ALL SELECT 2568, 'ZM' -- Zambia
  UNION ALL SELECT 2756, 'MT' -- Malta
  UNION ALL SELECT 2802, 'AE' -- United Arab Emirates
  UNION ALL SELECT 2817, 'NZ' -- New Zealand
  UNION ALL SELECT 2931, 'AD' -- Andorra
  UNION ALL SELECT 3039, 'TG' -- Togo
  UNION ALL SELECT 3126, 'LU' -- Luxembourg
  UNION ALL SELECT 3347, 'SM' -- San Marino
  UNION ALL SELECT 3374, 'GI' -- Gibraltar
  UNION ALL SELECT 3483, 'US' -- United States
  UNION ALL SELECT 3569, 'GF' -- French Guiana
  UNION ALL SELECT 3662, 'GA' -- Gabon
  UNION ALL SELECT 3677, 'SY' -- Syria
  UNION ALL SELECT 3779, 'GP' -- Guadeloupe
  UNION ALL SELECT 3990, 'NI' -- Nicaragua
  UNION ALL SELECT 3995, 'MY' -- Malaysia
  UNION ALL SELECT 4125, 'UG' -- Uganda
  UNION ALL SELECT 4829, 'YT' -- Mayotte
  UNION ALL SELECT 5120, 'MQ' -- Martinique
  UNION ALL SELECT 5618, 'CN' -- China
  UNION ALL SELECT 5724, 'SL' -- Sierra Leone
  UNION ALL SELECT 5790, 'NA' -- Namibia
  UNION ALL SELECT 6783, 'MZ' -- Mozambique
  UNION ALL SELECT 7091, 'OM' -- Oman
  UNION ALL SELECT 7437, 'CW' -- Curaçao
  UNION ALL SELECT 7563, 'SO' -- Somalia
  UNION ALL SELECT 7598, 'BO' -- Bolivia
  UNION ALL SELECT 7830, 'BJ' -- Benin
  UNION ALL SELECT 11256, 'SZ' -- Eswatini
  UNION ALL SELECT 12095, 'LC' -- Saint Lucia
  UNION ALL SELECT 14837, 'MS' -- Montserrat
  UNION ALL SELECT 15326, 'BM' -- Bermuda
  UNION ALL SELECT 16175, 'LY' -- Libya
  UNION ALL SELECT 20802, 'MW' -- Malawi
  UNION ALL SELECT 21462, 'KW' -- Kuwait
  UNION ALL SELECT 21795, 'LI' -- Liechtenstein
  UNION ALL SELECT 26833, 'GD' -- Grenada
  UNION ALL SELECT 33497, 'BB' -- Barbados
  UNION ALL SELECT 35008, 'SV' -- El Salvador
  UNION ALL SELECT 35185, 'JE' -- Jersey
  UNION ALL SELECT 35210, 'TZ' -- Tanzania
  UNION ALL SELECT 35376, 'SA' -- Saudi Arabia
  UNION ALL SELECT 37528, 'KY' -- Cayman Islands
  UNION ALL SELECT 38404, 'LK' -- Sri Lanka
  UNION ALL SELECT 39214, 'VC' -- Saint Vincent and the Grenadines
  UNION ALL SELECT 41302, 'VG' -- British Virgin Islands
  UNION ALL SELECT 43321, 'ER' -- Eritrea
  UNION ALL SELECT 43444, 'AF' -- Afghanistan
  UNION ALL SELECT 44569, 'AW' -- Aruba
  UNION ALL SELECT 44983, 'ET' -- Ethiopia
  UNION ALL SELECT 45412, 'LB' -- Lebanon
  UNION ALL SELECT 47329, 'BQ' -- Caribbean Netherlands
  UNION ALL SELECT 48946, 'PS' -- Palestine
  UNION ALL SELECT 49438, 'KG' -- Kyrgyzstan
  UNION ALL SELECT 49477, 'TH' -- Thailand
  UNION ALL SELECT 50809, 'PH' -- Philippines
  UNION ALL SELECT 52126, 'PK' -- Pakistan
  UNION ALL SELECT 53128, 'GT' -- Guatemala
  UNION ALL SELECT 55408, 'PG' -- Papua New Guinea
  UNION ALL SELECT 56518, 'SD' -- Sudan
  UNION ALL SELECT 57142, 'MK' -- North Macedonia
  UNION ALL SELECT 57160, 'TJ' -- Tajikistan
  UNION ALL SELECT 63604, 'CU' -- Cuba
  UNION ALL SELECT 64306, 'HK' -- Hong Kong
  UNION ALL SELECT 65053, 'NE' -- Niger
  UNION ALL SELECT 65437, 'PA' -- Panama
  UNION ALL SELECT 69697, 'VN' -- Vietnam
  UNION ALL SELECT 74505, 'QA' -- Qatar
  UNION ALL SELECT 75285, 'MC' -- Monaco
  UNION ALL SELECT 77505, 'TL' -- Timor-Leste
  UNION ALL SELECT 77580, 'PR' -- Puerto Rico
  UNION ALL SELECT 79146, 'DO' -- Dominican Republic
  UNION ALL SELECT 80919, 'BS' -- Bahamas
  UNION ALL SELECT 83175, 'TM' -- Turkmenistan
  UNION ALL SELECT 88137, 'RW' -- Rwanda
  UNION ALL SELECT 88407, 'ID' -- Indonesia
  UNION ALL SELECT 97374, 'JO' -- Jordan
  UNION ALL SELECT 97434, 'SX' -- Sint Maarten
  UNION ALL SELECT 98799, 'TD' -- Chad
  UNION ALL SELECT 137919, 'AG' -- Antigua and Barbuda
  UNION ALL SELECT 144816, 'BZ' -- Belize
  UNION ALL SELECT 153732, 'IN' -- India
  UNION ALL SELECT 155043, 'BD' -- Bangladesh
  UNION ALL SELECT 160047, 'KN' -- Saint Kitts and Nevis
  UNION ALL SELECT 179748, 'ST' -- São Tomé and Príncipe
  UNION ALL SELECT 190317, 'SS' -- South Sudan
  UNION ALL SELECT 190318, 'YE' -- Yemen
  UNION ALL SELECT 190321, 'BH' -- Bahrain
  UNION ALL SELECT 191038, 'BW' -- Botswana
  UNION ALL SELECT 201580, 'MV' -- Maldives
  UNION ALL SELECT 211975, 'GQ' -- Equatorial Guinea
  UNION ALL SELECT 213370, 'TW' -- Taiwan
  UNION ALL SELECT 213955, 'SG' -- Singapore
  UNION ALL SELECT 360931, 'MU' -- Mauritius
  UNION ALL SELECT 364678, 'KM' -- Comoros
  UNION ALL SELECT 380155, 'DM' -- Dominica
  UNION ALL SELECT 390940, 'IM' -- Isle of Man
  UNION ALL SELECT 453172, 'MO' -- Macau
  UNION ALL SELECT 482134, 'LS' -- Lesotho
  UNION ALL SELECT 705616, 'TC' -- Turks and Caicos Islands
  UNION ALL SELECT 862868, 'NP' -- Nepal
  UNION ALL SELECT 866998, 'FJ' -- Fiji
  UNION ALL SELECT 867004, 'SB' -- Solomon Islands
  UNION ALL SELECT 867012, 'VU' -- Vanuatu
  UNION ALL SELECT 867334, 'WS' -- Samoa
  UNION ALL SELECT 867648, 'CK' -- Cook Islands
  UNION ALL SELECT 869895, 'LA' -- Laos
  UNION ALL SELECT 870092, 'AI' -- Anguilla
  UNION ALL SELECT 870933, 'MM' -- Myanmar
  UNION ALL SELECT 908783, 'DJ' -- Djibouti
  UNION ALL SELECT 908860, 'SC' -- Seychelles
  UNION ALL SELECT 909440, 'KH' -- Cambodia
  UNION ALL SELECT 909526, 'MN' -- Mongolia
  UNION ALL SELECT 909582, 'AS' -- American Samoa
  UNION ALL SELECT 909585, 'TO' -- Tonga
  UNION ALL SELECT 910036, 'GU' -- Guam
  UNION ALL SELECT 911987, 'BT' -- Bhutan
  UNION ALL SELECT 913469, 'BN' -- Brunei
  UNION ALL SELECT 1442002, 'KP' -- Korea DPR
  UNION ALL SELECT 1884978, 'GG' -- Guernsey
  UNION ALL SELECT 3499960, 'MP' -- Northern Mariana Islands
  UNION ALL SELECT 12444275, 'NU' -- Niue
  UNION ALL SELECT 15629849, 'FM' -- Federated States of Micronesia
  UNION ALL SELECT 34319255, 'FK' -- Falkland Islands (Malvinas)
  UNION ALL SELECT 37176064, 'TV' -- Tuvalu
  UNION ALL SELECT 37200394, 'KG' -- Kyrgyz Republic
  UNION ALL SELECT 37200428, 'VI' -- US Virgin Islands
) AS codes ON codes.country_id = c.country_id
SET c.iso_code = codes.iso_code;

COMMIT;

SELECT COUNT(*) AS total_countries,
       COUNT(iso_code) AS countries_with_iso_code,
       SUM(iso_code IS NULL) AS countries_without_iso_code
FROM countries;

SELECT country_id, name, iso_code
FROM countries
WHERE iso_code IS NULL
ORDER BY country_id;
