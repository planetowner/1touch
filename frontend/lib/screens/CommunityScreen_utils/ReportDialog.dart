import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

Future<void> showReportDialog(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = Theme.of(context).colorScheme;
          final appColors = AppColors.of(context);
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and close
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Report",
                          style:
                              Heading4.style.copyWith(color: colors.onSurface),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(Icons.close, color: colors.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: appColors.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Tell us why you would like to report this post!",
                            style: Body2.style
                                .copyWith(color: appColors.mutedForeground),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Radio list
                    RadioGroup<int>(
                      groupValue: selectedIndex,
                      onChanged: (value) {
                        setState(() {
                          selectedIndex = value;
                          errorMessage = null;
                        });
                      },
                      child: Column(
                        children: List.generate(reasons.length, (index) {
                          return Column(
                            children: [
                              RadioListTile<int>(
                                value: index,
                                title: Text(
                                  reasons[index],
                                  style: Body1.style,
                                ),
                                activeColor: colors.onSurface,
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                contentPadding: EdgeInsets.zero,
                              ),
                              Divider(color: appColors.divider),
                            ],
                          );
                        }),
                      ),
                    ),

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

                    // Submit button
                    GestureDetector(
                      key: const ValueKey('community-report-submit'),
                      onTap: selectedIndex == null || isSubmitting
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
                                  errorMessage =
                                      'Unable to submit report. Please try again.';
                                });
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedIndex == null || isSubmitting
                              ? appColors.mutedForeground
                              : colors.onSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: isSubmitting
                            ? SizedBox(
                                key: const ValueKey(
                                  'community-report-submitting',
                                ),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : Text(
                                "SUBMIT",
                                style: Body2_b.style
                                    .copyWith(color: colors.onPrimary),
                              ),
                      ),
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
    backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title and close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Report",
                  style: Heading4.style.copyWith(color: colors.onSurface),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.close, color: colors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: colors.onSurface,
            ),
            const SizedBox(height: 16),
            Text(
              "Thanks for your report!",
              style: Heading5.style,
            ),
            const SizedBox(height: 16),
            Text(
              "Thanks again for your report — we’ve got your back, and your fellow 1touchers too. Every report helps make 1touch a safer, better place for everyone.",
              style: Body2.style,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: colors.onSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  "DONE",
                  style: Body2_b.style.copyWith(color: colors.onPrimary),
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}
