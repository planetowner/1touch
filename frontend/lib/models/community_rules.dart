enum CommunityLanguage {
  korean('ko'),
  english('en'),
  japanese('ja'),
  simplifiedChinese('zh-Hans');

  const CommunityLanguage(this.apiValue);

  final String apiValue;

  factory CommunityLanguage.fromApiValue(String value) {
    return CommunityLanguage.values.firstWhere(
      (language) => language.apiValue == value,
      orElse: () => throw FormatException(
        'Unsupported community-rules language "$value".',
      ),
    );
  }

  /// Converts a device locale to a language supported by the backend.
  /// Unsupported locales, including Traditional Chinese, use English.
  factory CommunityLanguage.fromLocaleParts({
    required String languageCode,
    String? scriptCode,
  }) {
    switch (languageCode.toLowerCase()) {
      case 'ko':
        return CommunityLanguage.korean;
      case 'ja':
        return CommunityLanguage.japanese;
      case 'zh' when scriptCode?.toLowerCase() == 'hans':
        return CommunityLanguage.simplifiedChinese;
      default:
        return CommunityLanguage.english;
    }
  }
}

class CommunityRule {
  const CommunityRule({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class CommunityRules {
  CommunityRules({
    required this.language,
    required this.title,
    required List<CommunityRule> items,
    required this.confirmLabel,
  }) : items = List.unmodifiable(items);

  final CommunityLanguage language;
  final String title;
  final List<CommunityRule> items;
  final String confirmLabel;
}
