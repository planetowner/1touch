part of 'home_screen_features.dart';

class SyncDialog extends StatelessWidget {
  const SyncDialog({super.key});

  // Static helper to show the dialog easily from anywhere
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => const SyncDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: appColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sync with your calendar?", style: Heading5.style),
            const SizedBox(height: 16),
            Text(
              "We’ll add your favorite team’s upcoming matches straight to your calendar, so you never miss a kickoff. You’ll get notified before each game — no spam, no surprises.",
              style: Body1.style,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "YES, SYNC IT!",
                  style: Body2_b.style.copyWith(color: colorScheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text("CANCEL", style: Body2_b.style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Converted _showTeamSelection to a reusable StatefulWidget class
