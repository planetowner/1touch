import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/models/community_rules.dart';

void showGroundRulesModal(
  BuildContext context, {
  required int teamId,
  CommunityRepository? repository,
}) {
  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  final language = CommunityLanguage.fromLocaleParts(
    languageCode: locale.languageCode,
    scriptCode: locale.scriptCode,
  );
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _GroundRulesDialog(
      teamId: teamId,
      language: language,
      repository: repository ?? community_providers.communityRepository,
    ),
  );
}

class _GroundRulesDialog extends StatefulWidget {
  const _GroundRulesDialog({
    required this.teamId,
    required this.language,
    required this.repository,
  });

  final int teamId;
  final CommunityLanguage language;
  final CommunityRepository repository;

  @override
  State<_GroundRulesDialog> createState() => _GroundRulesDialogState();
}

class _GroundRulesDialogState extends State<_GroundRulesDialog> {
  late Future<CommunityRules> _rulesFuture;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    _rulesFuture = widget.repository.loadRules(
      teamId: widget.teamId,
      language: widget.language,
    );
  }

  void _retry() {
    setState(_loadRules);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      key: const ValueKey('community-ground-rules-dialog'),
      backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: FutureBuilder<CommunityRules>(
          future: _rulesFuture,
          builder: (context, snapshot) {
            final rules = snapshot.data;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.push_pin_outlined, color: colors.onSurface),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rules?.title ?? 'Community Ground Rules',
                          style: Heading5.style.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Flexible(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: CircularProgressIndicator(
                            key: ValueKey('community-rules-loading'),
                          ),
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    Flexible(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Unable to load community rules.',
                                key: const ValueKey('community-rules-error'),
                                style: Body1.style.copyWith(
                                  color: colors.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                key: const ValueKey('community-rules-retry'),
                                onPressed: _retry,
                                child: const Text('RETRY'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rules!.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final rule = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${index + 1}.',
                                      key: ValueKey(
                                        'ground-rule-number-${index + 1}',
                                      ),
                                      style: Body1_b.style.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rule.title,
                                          key: ValueKey(
                                            'ground-rule-title-${index + 1}',
                                          ),
                                          style: Body1_b.style.copyWith(
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          rule.body,
                                          key: ValueKey(
                                            'ground-rule-subtitle-${index + 1}',
                                          ),
                                          style: Body1.style.copyWith(
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (rules != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.onSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          rules.confirmLabel,
                          style: Body2_b.style.copyWith(
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
