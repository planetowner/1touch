import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_error_config.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.statusCode,
    this.onAction,
  });

  final int statusCode;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final config = appErrorConfigFor(statusCode);
    final colors = AppColors.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.subtleBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(statusCode),
                size: 44,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              tr(context, config.title),
              key: ValueKey('app-error-$statusCode-title'),
              textAlign: TextAlign.center,
              style: Heading3.style,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, config.message),
              key: ValueKey('app-error-$statusCode-message'),
              textAlign: TextAlign.center,
              style: Body1.style.copyWith(color: colors.mutedForeground),
            ),
            if (config.action != null && onAction != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: ValueKey('app-error-$statusCode-action'),
                  onPressed: onAction,
                  child:
                      Text(tr(context, config.action!), style: Body1_b.style),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({
    super.key,
    required this.statusCode,
    this.onRetry,
  });

  final int statusCode;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainPageBackground(context),
      body: SafeArea(
        child: AppErrorView(
          statusCode: statusCode,
          onAction: _actionFor(context),
        ),
      ),
    );
  }

  VoidCallback? _actionFor(BuildContext context) {
    return switch (statusCode) {
      401 => () => context.go('/onboarding'),
      403 => () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home');
          }
        },
      404 => () => context.go('/home'),
      500 => onRetry,
      _ => null,
    };
  }
}

IconData _iconFor(int statusCode) {
  return switch (statusCode) {
    401 => Icons.login,
    403 => Icons.sports_soccer,
    404 => Icons.sports_soccer,
    429 => Icons.hourglass_top,
    500 => Icons.slow_motion_video,
    502 => Icons.link_off,
    503 => Icons.pause_circle_outline,
    504 => Icons.timer_off_outlined,
    _ => Icons.error_outline,
  };
}
