import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/features/community/community_ui.dart';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/models/community_rules.dart';
import 'package:onetouch/l10n/app_localizations.dart';

Future<bool?> showGroundRulesModal(
  BuildContext context, {
  required int teamId,
  CommunityRepository? repository,
  Duration readingDuration = Duration.zero,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: readingDuration == Duration.zero,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => _GroundRulesDialog(
      teamId: teamId,
      repository: repository ?? community_providers.communityRepository,
      readingDuration: readingDuration,
    ),
  );
}

class _GroundRulesDialog extends StatefulWidget {
  const _GroundRulesDialog({
    required this.teamId,
    required this.repository,
    required this.readingDuration,
  });

  final int teamId;
  final CommunityRepository repository;
  final Duration readingDuration;

  @override
  State<_GroundRulesDialog> createState() => _GroundRulesDialogState();
}

class _GroundRulesDialogState extends State<_GroundRulesDialog>
    with SingleTickerProviderStateMixin {
  late Future<CommunityRules> _rulesFuture;
  AnimationController? _readingController;
  bool _readingStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.readingDuration > Duration.zero) {
      _readingController = AnimationController(
        vsync: this,
        duration: widget.readingDuration,
      );
    }
    _loadRules();
  }

  @override
  void dispose() {
    _readingController?.dispose();
    super.dispose();
  }

  void _loadRules() {
    _rulesFuture = widget.repository.loadRules(
      teamId: widget.teamId,
    );
  }

  void _retry() {
    setState(_loadRules);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    return Dialog(
      key: const ValueKey('community-ground-rules-dialog'),
      backgroundColor: appColors.subtleBackground,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 48,
          maxWidth: 345,
        ),
        child: FutureBuilder<CommunityRules>(
          future: _rulesFuture,
          builder: (context, snapshot) {
            final rules = snapshot.data;
            if (rules != null &&
                !_readingStarted &&
                _readingController != null) {
              _readingStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _readingController?.forward();
              });
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const CommunityIcon('pin', size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tr(context, rules?.title ?? 'Community Ground Rules'),
                          style: CommunityText.title(context).copyWith(
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
                          child: FootballLoadingIndicator(
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
                                tr(context, 'Unable to load community rules.'),
                                key: const ValueKey('community-rules-error'),
                                style: CommunityText.body(context).copyWith(
                                  color: colors.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                key: const ValueKey('community-rules-retry'),
                                onPressed: _retry,
                                child: Text(trUpper(context, 'Retry')),
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
                              padding: EdgeInsets.only(
                                  bottom:
                                      index < rules.items.length - 1 ? 36 : 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    child: Text(
                                      '${index + 1}.',
                                      key: ValueKey(
                                        'ground-rule-number-${index + 1}',
                                      ),
                                      style:
                                          CommunityText.bold(context).copyWith(
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
                                          tr(context, rule.title),
                                          key: ValueKey(
                                            'ground-rule-title-${index + 1}',
                                          ),
                                          style: CommunityText.bold(context)
                                              .copyWith(
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        Text(
                                          tr(context, rule.body),
                                          key: ValueKey(
                                            'ground-rule-subtitle-${index + 1}',
                                          ),
                                          style: CommunityText.body(context)
                                              .copyWith(
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
                    const SizedBox(height: 48),
                    if (_readingController != null) ...[
                      Row(children: [
                        Icon(Icons.info_outline, color: colors.onSurface),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(context,
                                'Please read the rules for 10 seconds before continuing.'),
                            style:
                                Body2.style.copyWith(color: colors.onSurface),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _readingController!,
                        builder: (context, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            key: const ValueKey(
                                'community-rules-reading-button'),
                            children: [
                              const Positioned.fill(
                                  child: ColoredBox(color: Colors.white54)),
                              Positioned.fill(
                                  child: FractionallySizedBox(
                                key: const ValueKey(
                                    'community-rules-reading-fill'),
                                alignment: Alignment.centerLeft,
                                widthFactor: _readingController!.value,
                                child: const ColoredBox(color: Colors.white),
                              )),
                              AppActionButton(
                                buttonKey: const ValueKey(
                                    'community-rules-understand'),
                                label: tr(context, 'I UNDERSTAND!'),
                                backgroundColor: Colors.transparent,
                                foregroundColor: const Color(0xFF0A0A0A),
                                onPressed: _readingController!.value >= 1
                                    ? () => Navigator.of(context).pop(true)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      AppActionButton(
                        label: tr(context, 'I UNDERSTAND!'),
                        onPressed: () => Navigator.of(context).pop(true),
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
