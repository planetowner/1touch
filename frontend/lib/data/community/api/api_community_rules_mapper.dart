import 'package:onetouch/data/community/api/api_community_rules_response.dart';
import 'package:onetouch/models/community_rules.dart';

CommunityRules communityRulesFromApiResponse(
  ApiCommunityRulesResponse response,
) {
  final rules = response.rules;
  final title = _nonEmpty(rules.title, fieldName: 'title');
  final confirmLabel = _nonEmpty(
    rules.confirmLabel,
    fieldName: 'confirm_label',
  );
  if (rules.items.isEmpty) {
    throw const FormatException(
      'Expected community rules to contain at least one item.',
    );
  }

  return CommunityRules(
    language: CommunityLanguage.fromApiValue(rules.language),
    title: title,
    items: rules.items
        .map(
          (item) => CommunityRule(
            title: _nonEmpty(item.title, fieldName: 'items.title'),
            body: _nonEmpty(item.body, fieldName: 'items.body'),
          ),
        )
        .toList(),
    confirmLabel: confirmLabel,
  );
}

String _nonEmpty(String value, {required String fieldName}) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException(
      'Expected non-empty community-rules field "$fieldName".',
    );
  }
  return normalized;
}
