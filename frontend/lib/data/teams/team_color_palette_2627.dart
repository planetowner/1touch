class TeamColorPalette {
  final int primary;
  final int secondary;
  final int tertiary;

  const TeamColorPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });
}

/// The supplied 2026/27 Big Five palette.
///
/// Team IDs are intentionally not stored here because the source palette only
/// contains names. API-backed teams should resolve their palette by name until
/// the backend exposes colors or a stable ID-to-palette contract.
const Map<String, TeamColorPalette> teamColorPalette2627 = {
  'marseille': TeamColorPalette(
    primary: 0xFF01A0DD,
    secondary: 0xFFB99570,
    tertiary: 0xFF1290A4,
  ),
  'lyon': TeamColorPalette(
    primary: 0xFF206BD4,
    secondary: 0xFFE01A22,
    tertiary: 0xFFCE9C50,
  ),
  'brest': TeamColorPalette(
    primary: 0xFFF2383F,
    secondary: 0xFF2282EE,
    tertiary: 0xFFFD4FA0,
  ),
  'lens': TeamColorPalette(
    primary: 0xFFE52E34,
    secondary: 0xFFC9A905,
    tertiary: 0xFF08767F,
  ),
  'toulouse': TeamColorPalette(
    primary: 0xFF944FD2,
    secondary: 0xFFD8C117,
    tertiary: 0xFFFE3647,
  ),
  'nice': TeamColorPalette(
    primary: 0xFFF22842,
    secondary: 0xFFC19A5B,
    tertiary: 0xFF5C60F1,
  ),
  'psg': TeamColorPalette(
    primary: 0xFF0287E1,
    secondary: 0xFFFD9198,
    tertiary: 0xFFF13C40,
  ),
  'rennes': TeamColorPalette(
    primary: 0xFFF5473B,
    secondary: 0xFFEAB223,
    tertiary: 0xFF0BA4DF,
  ),
  'strasbourg': TeamColorPalette(
    primary: 0xFF0B60E2,
    secondary: 0xFFF83139,
    tertiary: 0xFFFE7A40,
  ),
  'losc': TeamColorPalette(
    primary: 0xFFFD3D32,
    secondary: 0xFF6461E0,
    tertiary: 0xFFF6BE1E,
  ),
  'angers': TeamColorPalette(
    primary: 0xFFBE9667,
    secondary: 0xFFF44B43,
    tertiary: 0xFF2CB1AD,
  ),
  'le havre': TeamColorPalette(
    primary: 0xFF235FC1,
    secondary: 0xFFC6A068,
    tertiary: 0xFF429EDB,
  ),
  'lorient': TeamColorPalette(
    primary: 0xFFF16C20,
    secondary: 0xFF16ACB7,
    tertiary: 0xFFE09E63,
  ),
  'auxerre': TeamColorPalette(
    primary: 0xFF2466C8,
    secondary: 0xFFB2D03D,
    tertiary: 0xFFDBB454,
  ),
  'paris fc': TeamColorPalette(
    primary: 0xFF4058D0,
    secondary: 0xFFE73C7F,
    tertiary: 0xFF1B92D6,
  ),
  'monaco': TeamColorPalette(
    primary: 0xFFEC0001,
    secondary: 0xFFD5A508,
    tertiary: 0xFF017E8A,
  ),
  'troyes': TeamColorPalette(
    primary: 0xFF015196,
    secondary: 0xFFE6CE90,
    tertiary: 0xFF1DBAF1,
  ),
  'le mans': TeamColorPalette(
    primary: 0xFFEC0016,
    secondary: 0xFFFB8807,
    tertiary: 0xFF118E86,
  ),
  'sunderland': TeamColorPalette(
    primary: 0xFFEB1729,
    secondary: 0xFFC9B45E,
    tertiary: 0xFF0B9B5A,
  ),
  'tottenham': TeamColorPalette(
    primary: 0xFF3C5DB7,
    secondary: 0xFF7A4AC6,
    tertiary: 0xFFDDD51C,
  ),
  'liverpool': TeamColorPalette(
    primary: 0xFFE41B22,
    secondary: 0xFF24A490,
    tertiary: 0xFF8B43F9,
  ),
  'man city': TeamColorPalette(
    primary: 0xFF5FAFF1,
    secondary: 0xFFF9C250,
    tertiary: 0xFF296DCA,
  ),
  'fulham': TeamColorPalette(
    primary: 0xFF6E5555,
    secondary: 0xFFDE1E1F,
    tertiary: 0xFFCFB2B2,
  ),
  'everton': TeamColorPalette(
    primary: 0xFF2F5DC9,
    secondary: 0xFFEEBB3A,
    tertiary: 0xFF6947CB,
  ),
  'man united': TeamColorPalette(
    primary: 0xFFEF2C34,
    secondary: 0xFF1F6359,
    tertiary: 0xFF294597,
  ),
  'aston villa': TeamColorPalette(
    primary: 0xFF972B62,
    secondary: 0xFF64A8E6,
    tertiary: 0xFFDFCB0D,
  ),
  'chelsea': TeamColorPalette(
    primary: 0xFF3551D1,
    secondary: 0xFFF7CC34,
    tertiary: 0xFFF83B44,
  ),
  'arsenal': TeamColorPalette(
    primary: 0xFFE72452,
    secondary: 0xFF2964E0,
    tertiary: 0xFFBFA65C,
  ),
  'newcastle': TeamColorPalette(
    primary: 0xFFBA9038,
    secondary: 0xFF30B6DC,
    tertiary: 0xFFFD5B50,
  ),
  'crystal palace': TeamColorPalette(
    primary: 0xFF255FC5,
    secondary: 0xFFDF304D,
    tertiary: 0xFFC7CF18,
  ),
  'bournemouth': TeamColorPalette(
    primary: 0xFFD82129,
    secondary: 0xFF347C96,
    tertiary: 0xFFE7A23A,
  ),
  'nottm forest': TeamColorPalette(
    primary: 0xFFD0102B,
    secondary: 0xFF504DBA,
    tertiary: 0xFF38578E,
  ),
  'leeds united': TeamColorPalette(
    primary: 0xFF0D79C8,
    secondary: 0xFFE4CA01,
    tertiary: 0xFFF89EA2,
  ),
  'brighton': TeamColorPalette(
    primary: 0xFF1A78D2,
    secondary: 0xFFF6BF29,
    tertiary: 0xFF2EB264,
  ),
  'brentford': TeamColorPalette(
    primary: 0xFFD93637,
    secondary: 0xFFE5B13B,
    tertiary: 0xFF408865,
  ),
  'coventry city': TeamColorPalette(
    primary: 0xFF00B5E2,
    secondary: 0xFFE84C23,
    tertiary: 0xFF4CA332,
  ),
  'ipswich town': TeamColorPalette(
    primary: 0xFF2755A3,
    secondary: 0xFFE40520,
    tertiary: 0xFFE0C590,
  ),
  'hull city': TeamColorPalette(
    primary: 0xFFF18A01,
    secondary: 0xFF0963F7,
    tertiary: 0xFF1099C3,
  ),
  'celta vigo': TeamColorPalette(
    primary: 0xFF62ACE4,
    secondary: 0xFFE3254E,
    tertiary: 0xFFCEAC2B,
  ),
  'barcelona': TeamColorPalette(
    primary: 0xFFD92455,
    secondary: 0xFF1B6EBD,
    tertiary: 0xFFDEB406,
  ),
  'getafe': TeamColorPalette(
    primary: 0xFF0D6BCB,
    secondary: 0xFFD73336,
    tertiary: 0xFF6CB127,
  ),
  'valencia': TeamColorPalette(
    primary: 0xFFFD6816,
    secondary: 0xFF18A6E4,
    tertiary: 0xFF03B36D,
  ),
  'rayo vallecano': TeamColorPalette(
    primary: 0xFFCDA23F,
    secondary: 0xFFF2363D,
    tertiary: 0xFF3AAAE8,
  ),
  'osasuna': TeamColorPalette(
    primary: 0xFFE8343A,
    secondary: 0xFF306DC5,
    tertiary: 0xFF42B458,
  ),
  'real betis': TeamColorPalette(
    primary: 0xFF11A960,
    secondary: 0xFFC0A060,
    tertiary: 0xFF885BCD,
  ),
  'espanyol': TeamColorPalette(
    primary: 0xFF1D74D6,
    secondary: 0xFFD0A43C,
    tertiary: 0xFFFD353C,
  ),
  'real sociedad': TeamColorPalette(
    primary: 0xFF136CD0,
    secondary: 0xFFF34554,
    tertiary: 0xFFE3B530,
  ),
  'sevilla': TeamColorPalette(
    primary: 0xFFE72335,
    secondary: 0xFFE4AE3B,
    tertiary: 0xFF1F61C1,
  ),
  'elche': TeamColorPalette(
    primary: 0xFF189D5B,
    secondary: 0xFFE4B64A,
    tertiary: 0xFF2963CA,
  ),
  'levante': TeamColorPalette(
    primary: 0xFF1072C1,
    secondary: 0xFFCB1553,
    tertiary: 0xFFE1B001,
  ),
  'real madrid': TeamColorPalette(
    primary: 0xFFFDBC06,
    secondary: 0xFF1877CD,
    tertiary: 0xFFFE8701,
  ),
  'villarreal': TeamColorPalette(
    primary: 0xFFE3BE02,
    secondary: 0xFF0A7CC8,
    tertiary: 0xFFFD2026,
  ),
  'atlético madrid': TeamColorPalette(
    primary: 0xFFE7151D,
    secondary: 0xFF3A3DEE,
    tertiary: 0xFF058EEA,
  ),
  'athletic club': TeamColorPalette(
    primary: 0xFFE20119,
    secondary: 0xFF529D55,
    tertiary: 0xFF03A3B6,
  ),
  'alavés': TeamColorPalette(
    primary: 0xFF1C5EF4,
    secondary: 0xFF14AB84,
    tertiary: 0xFFFD8E2C,
  ),
  'racing santander': TeamColorPalette(
    primary: 0xFF2E9A2A,
    secondary: 0xFF2E99E1,
    tertiary: 0xFFB11C30,
  ),
  'deportivo la coruña': TeamColorPalette(
    primary: 0xFF0050B3,
    secondary: 0xFFC2B064,
    tertiary: 0xFF199F87,
  ),
  'málaga': TeamColorPalette(
    primary: 0xFF0740C1,
    secondary: 0xFF0088F2,
    tertiary: 0xFFFF00A4,
  ),
  'roma': TeamColorPalette(
    primary: 0xFFBD1C43,
    secondary: 0xFFF9BB01,
    tertiary: 0xFF295EAF,
  ),
  'lazio': TeamColorPalette(
    primary: 0xFF3EB9E7,
    secondary: 0xFFD8A717,
    tertiary: 0xFF21A29B,
  ),
  'genoa': TeamColorPalette(
    primary: 0xFFD93036,
    secondary: 0xFF228BB4,
    tertiary: 0xFFE0B410,
  ),
  'fiorentina': TeamColorPalette(
    primary: 0xFF8E4DDE,
    secondary: 0xFFB49C79,
    tertiary: 0xFFEDD42D,
  ),
  'milan': TeamColorPalette(
    primary: 0xFFF82D41,
    secondary: 0xFFBB9457,
    tertiary: 0xFF02AE81,
  ),
  'como': TeamColorPalette(
    primary: 0xFF0F81DC,
    secondary: 0xFFEBD11E,
    tertiary: 0xFF04B170,
  ),
  'udinese': TeamColorPalette(
    primary: 0xFFB08A73,
    secondary: 0xFFBB6BE0,
    tertiary: 0xFFF2C528,
  ),
  'parma': TeamColorPalette(
    primary: 0xFFE4BC02,
    secondary: 0xFF386DE9,
    tertiary: 0xFFFD8DCE,
  ),
  'cagliari': TeamColorPalette(
    primary: 0xFFE9374D,
    secondary: 0xFF2778C7,
    tertiary: 0xFFF16F36,
  ),
  'napoli': TeamColorPalette(
    primary: 0xFF2DBAFC,
    secondary: 0xFFD29C08,
    tertiary: 0xFF0EC08C,
  ),
  'torino': TeamColorPalette(
    primary: 0xFFBF3138,
    secondary: 0xFFDD9B14,
    tertiary: 0xFF3A71FB,
  ),
  'juventus': TeamColorPalette(
    primary: 0xFFF4B401,
    secondary: 0xFFED5E6B,
    tertiary: 0xFF5A57EA,
  ),
  'atalanta': TeamColorPalette(
    primary: 0xFF3079CC,
    secondary: 0xFFE2B606,
    tertiary: 0xFFE98426,
  ),
  'sassuolo': TeamColorPalette(
    primary: 0xFF32B75C,
    secondary: 0xFF2D77D4,
    tertiary: 0xFFCAD821,
  ),
  'inter': TeamColorPalette(
    primary: 0xFF3057FD,
    secondary: 0xFFE9BE2C,
    tertiary: 0xFFEE8736,
  ),
  'lecce': TeamColorPalette(
    primary: 0xFF085F86,
    secondary: 0xFFFDF100,
    tertiary: 0xFFED1B23,
  ),
  'bologna': TeamColorPalette(
    primary: 0xFF3276C9,
    secondary: 0xFFD43942,
    tertiary: 0xFFE6A19F,
  ),
  'venezia': TeamColorPalette(
    primary: 0xFFFF6900,
    secondary: 0xFF03904E,
    tertiary: 0xFFE6002F,
  ),
  'frosinone': TeamColorPalette(
    primary: 0xFFFFDD00,
    secondary: 0xFF0073C3,
    tertiary: 0xFF1C33F3,
  ),
  'monza': TeamColorPalette(
    primary: 0xFFED1638,
    secondary: 0xFF1BC6E0,
    tertiary: 0xFF1E66B8,
  ),
  'dortmund': TeamColorPalette(
    primary: 0xFFD3C801,
    secondary: 0xFF933CF0,
    tertiary: 0xFF2AA64B,
  ),
  'augsburg': TeamColorPalette(
    primary: 0xFF40894F,
    secondary: 0xFFD7323A,
    tertiary: 0xFFAF2F72,
  ),
  'rb leipzig': TeamColorPalette(
    primary: 0xFFEB1C55,
    secondary: 0xFF106EB7,
    tertiary: 0xFF50D7E1,
  ),
  'eintracht frankfurt': TeamColorPalette(
    primary: 0xFFF00D0C,
    secondary: 0xFF01A975,
    tertiary: 0xFFF75837,
  ),
  'mönchengladbach': TeamColorPalette(
    primary: 0xFF26A658,
    secondary: 0xFF5BB1E4,
    tertiary: 0xFF7849D0,
  ),
  'mainz': TeamColorPalette(
    primary: 0xFFFE2C39,
    secondary: 0xFF5A66D1,
    tertiary: 0xFFECBB01,
  ),
  'union berlin': TeamColorPalette(
    primary: 0xFFFD2828,
    secondary: 0xFFD1CA1E,
    tertiary: 0xFF259282,
  ),
  'hamburger sv': TeamColorPalette(
    primary: 0xFF046FDA,
    secondary: 0xFFF42141,
    tertiary: 0xFF49A2F2,
  ),
  'hoffenheim': TeamColorPalette(
    primary: 0xFF267FDD,
    secondary: 0xFFFD7767,
    tertiary: 0xFF47CBA7,
  ),
  'vfb stuttgart': TeamColorPalette(
    primary: 0xFFEF012D,
    secondary: 0xFF9C52C0,
    tertiary: 0xFFD3B601,
  ),
  'fc köln': TeamColorPalette(
    primary: 0xFFEB1B25,
    secondary: 0xFF64B4D0,
    tertiary: 0xFF159B95,
  ),
  'leverkusen': TeamColorPalette(
    primary: 0xFFED2024,
    secondary: 0xFFF5972C,
    tertiary: 0xFF1298EF,
  ),
  'sc freiburg': TeamColorPalette(
    primary: 0xFFE50029,
    secondary: 0xFF4F6E3D,
    tertiary: 0xFF199EB0,
  ),
  'bayern': TeamColorPalette(
    primary: 0xFFE32941,
    secondary: 0xFF18539F,
    tertiary: 0xFF8F4DBE,
  ),
  'werder': TeamColorPalette(
    primary: 0xFF1E9052,
    secondary: 0xFFFA773E,
    tertiary: 0xFF3E62A8,
  ),
  'schalke 04': TeamColorPalette(
    primary: 0xFF004B9C,
    secondary: 0xFF50C8E0,
    tertiary: 0xFFC4EE6E,
  ),
  'sv elversberg': TeamColorPalette(
    primary: 0xFFDFBC84,
    secondary: 0xFFF32033,
    tertiary: 0xFF62AEE0,
  ),
  'sc paderborn': TeamColorPalette(
    primary: 0xFF1963B8,
    secondary: 0xFFFA102B,
    tertiary: 0xFFEB9E46,
  ),
};

const Map<String, String> _teamColorAliases2627 = {
  'ac milan': 'milan',
  'afc bournemouth': 'bournemouth',
  'angers sco': 'angers',
  'as monaco': 'monaco',
  'bayer 04 leverkusen': 'leverkusen',
  'bayer leverkusen': 'leverkusen',
  'borussia dortmund': 'dortmund',
  'borussia mönchengladbach': 'mönchengladbach',
  'brighton & hove albion': 'brighton',
  'celta de vigo': 'celta vigo',
  'deportivo alavés': 'alavés',
  'fc barcelona': 'barcelona',
  'fc bayern munich': 'bayern',
  'fc bayern münchen': 'bayern',
  'fc union berlin': 'union berlin',
  'fsv mainz 05': 'mainz',
  'losc lille': 'losc',
  'manchester city': 'man city',
  'manchester united': 'man united',
  'newcastle united': 'newcastle',
  'nottingham forest': 'nottm forest',
  'olympique lyonnais': 'lyon',
  'olympique marseille': 'marseille',
  'paris': 'paris fc',
  'paris saint germain': 'psg',
  'paris saint-germain': 'psg',
  'tottenham hotspur': 'tottenham',
  'tsg hoffenheim': 'hoffenheim',
  'werder bremen': 'werder',
};

String _normalizeTeamColorName(String name) {
  return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

TeamColorPalette? teamColorPaletteForName(String teamName) {
  final normalizedName = _normalizeTeamColorName(teamName);
  final paletteName = _teamColorAliases2627[normalizedName] ?? normalizedName;
  return teamColorPalette2627[paletteName];
}

bool isTeamInBigFive2627(String teamName) {
  return teamColorPaletteForName(teamName) != null;
}
