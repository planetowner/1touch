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
    required this.title,
    required List<CommunityRule> items,
  }) : items = List.unmodifiable(items);

  final String title;
  final List<CommunityRule> items;
}
