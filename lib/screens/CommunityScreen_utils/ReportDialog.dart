import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

void showReportDialog(BuildContext context) {
  final List<String> reasons = [
    "Advertising",
    "Inappropriate Content",
    "Harassment & Bullying",
    "Spam",
    "Something Else",
  ];

  int? selectedIndex;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF2C2C2C) : AppPalette.white,
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
                    ...List.generate(reasons.length, (index) {
                      return Column(
                        children: [
                          RadioListTile<int>(
                            value: index,
                            groupValue: selectedIndex,
                            onChanged: (value) {
                              setState(() {
                                selectedIndex = value!;
                              });
                            },
                            title: Text(
                              reasons[index],
                              style: Body1.style,
                            ),
                            activeColor: colors.onSurface,
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: EdgeInsets.zero,
                          ),
                          Divider(color: appColors.divider),
                        ],
                      );
                    }),

                    const SizedBox(height: 24),

                    // Submit button
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        showThanksDialog(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.onSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "SUBMIT",
                          style:
                              Body2_b.style.copyWith(color: colors.onPrimary),
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
    backgroundColor: isDark ? const Color(0xFF2C2C2C) : AppPalette.white,
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
