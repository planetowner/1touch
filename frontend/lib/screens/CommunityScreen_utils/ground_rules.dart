import 'dart:ui';

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
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: _GroundRulesDialog(
        teamId: teamId,
        repository: repository ?? community_providers.communityRepository,
        readingDuration: readingDuration,
      ),
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
                      Icon(Icons.push_pin_outlined, color: colors.onSurface),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr(context, rules?.title ?? 'Community Ground Rules'),
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
                                style: Body1.style.copyWith(
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
                                          tr(context, rule.title),
                                          key: ValueKey(
                                            'ground-rule-title-${index + 1}',
                                          ),
                                          style: Body1_b.style.copyWith(
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          tr(context, rule.body),
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
                          child: SizedBox(
                            key: const ValueKey(
                                'community-rules-reading-button'),
                            height: 54,
                            child: Stack(children: [
                              const Positioned.fill(
                                child: ColoredBox(color: Colors.white54),
                              ),
                              Positioned.fill(
                                child: FractionallySizedBox(
                                  key: const ValueKey(
                                      'community-rules-reading-fill'),
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _readingController!.value,
                                  child: const ColoredBox(color: Colors.white),
                                ),
                              ),
                              Positioned.fill(
                                child: TextButton(
                                  key: const ValueKey(
                                      'community-rules-understand'),
                                  onPressed: _readingController!.value >= 1
                                      ? () => Navigator.of(context).pop(true)
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF090A0A),
                                    disabledForegroundColor:
                                        const Color(0xFF090A0A),
                                  ),
                                  child: Text(tr(context, 'I UNDERSTAND!')),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ] else
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.onSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tr(context, 'I UNDERSTAND!'),
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
