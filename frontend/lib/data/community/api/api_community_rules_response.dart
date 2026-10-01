class ApiCommunityRulesResponse {
  const ApiCommunityRulesResponse({required this.rules});

  final ApiCommunityRulesContentResponse rules;

  factory ApiCommunityRulesResponse.fromJson(Map<String, dynamic> json) {
    final rules = json['rules'];
    if (rules is! Map<String, dynamic>) {
      throw const FormatException('Expected required object field "rules".');
    }
    return ApiCommunityRulesResponse(
      rules: ApiCommunityRulesContentResponse.fromJson(rules),
    );
  }
}

class ApiCommunityRulesContentResponse {
  ApiCommunityRulesContentResponse({
    required this.title,
    required List<ApiCommunityRuleResponse> items,
  }) : items = List.unmodifiable(items);

  final String title;
  final List<ApiCommunityRuleResponse> items;

  factory ApiCommunityRulesContentResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Expected required list field "items".');
    }
    return ApiCommunityRulesContentResponse(
      title: _requiredString(json, 'title'),
      items: items.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected each "items" entry to be an object.',
          );
        }
        return ApiCommunityRuleResponse.fromJson(item);
      }).toList(),
    );
  }
}

class ApiCommunityRuleResponse {
  const ApiCommunityRuleResponse({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  factory ApiCommunityRuleResponse.fromJson(Map<String, dynamic> json) {
    return ApiCommunityRuleResponse(
      title: _requiredString(json, 'title'),
      body: _requiredString(json, 'body'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}
