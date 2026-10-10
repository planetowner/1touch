import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

Future<void> showReportDialog(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
  String targetLabel = 'post',
}) async {
  final parentContext = context;
  final List<String> reasons = [
    "Advertising",
    "Inappropriate Content",
    "Harassment & Bullying",
    "Spam",
    "Something Else",
  ];

  int? selectedIndex;
  bool isSubmitting = false;
  String? errorMessage;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ReportHeader(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const CommunityIcon('error'),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            tr(
                                context,
                                'Tell us why you would like to report this {target}!',
                                {'target': tr(context, targetLabel)}),
                            style: CommunityText.secondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    for (var index = 0; index < reasons.length; index++) ...[
                      Semantics(
                          checked: selectedIndex == index,
                          inMutuallyExclusiveGroup: true,
                          child: InkWell(
                              onTap: isSubmitting
                                  ? null
                                  : () => setState(() {
                                        selectedIndex = index;
                                        errorMessage = null;
                                      }),
                              child: SizedBox(
                                  height: 24,
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(tr(context, reasons[index]),
                                            style:
                                                CommunityText.body(context))),
                                    CommunityIcon(selectedIndex == index
                                        ? 'radio_checked'
                                        : 'radio'),
                                  ])))),
                      Padding(
                        padding: EdgeInsets.only(
                            top: 16,
                            bottom: index < reasons.length - 1 ? 16 : 0),
                        child: Divider(
                            height: 0,
                            thickness: 2,
                            color: communityDividerColor(context)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (errorMessage != null) ...[
                      Text(
                        errorMessage!,
                        key: const ValueKey('community-report-error'),
                        style: Body2.style.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppActionButton(
                      buttonKey: const ValueKey('community-report-submit'),
                      label: tr(context, 'SUBMIT'),
                      loading: isSubmitting,
                      progressKey:
                          const ValueKey('community-report-submitting'),
                      onPressed: selectedIndex == null || isSubmitting
                          ? null
                          : () async {
                              final reason = reasons[selectedIndex!];
                              setState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });

                              try {
                                await onSubmit(reason);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                if (!parentContext.mounted) return;
                                showThanksDialog(parentContext);
                              } catch (_) {
                                if (!context.mounted) return;
                                setState(() {
                                  isSubmitting = false;
                                  errorMessage = tr(context,
                                      'Unable to submit report. Please try again.');
                                });
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void showThanksDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Padding(
              key: const ValueKey('community-report-thanks'),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ReportHeader(),
                  const SizedBox(height: 24),
                  const CommunityIcon('check', size: 56),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, "Thanks for your report!"),
                    style: Heading4.style,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr(context,
                        "Thanks again for your report — we’ve got your back, and your fellow 1touchers too. Every report helps make 1touch a safer, better place for everyone."),
                    style: CommunityText.body(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppActionButton(
                    label: trUpper(context, 'Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader();
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 24,
      child: Stack(children: [
        Center(
            child: Text(tr(context, 'Report'),
                style: CommunityText.title(context))),
        Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const CommunityIcon('close'))),
      ]));
}
