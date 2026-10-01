import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_error_config.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/theme_controller.dart';

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

    if (config.imageAsset != null) {
      return _PhotoErrorView(
        statusCode: statusCode,
        config: config,
        onAction: onAction,
      );
    }

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

class _PhotoErrorView extends StatelessWidget {
  const _PhotoErrorView({
    required this.statusCode,
    required this.config,
    required this.onAction,
  });

  final int statusCode;
  final AppErrorConfig config;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.of(context).pageBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppPalette.white : AppPalette.black;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: background),
          _FadedErrorPhoto(
            asset: config.imageAsset!,
            background: background,
            height: constraints.maxHeight * 0.65,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          key: const ValueKey('app-error-back'),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_ios_new),
                          iconSize: 28,
                          color: AppPalette.white,
                        ),
                        const AppThemeToggle(foregroundColor: AppPalette.white),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  Text(
                    tr(context, config.title),
                    key: ValueKey('app-error-$statusCode-title'),
                    textAlign: TextAlign.center,
                    style: Heading3.style.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, config.message),
                    key: ValueKey('app-error-$statusCode-message'),
                    textAlign: TextAlign.center,
                    style: Body2.style.copyWith(color: foreground),
                  ),
                  const Spacer(),
                  if (config.action != null && onAction != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        key: ValueKey('app-error-$statusCode-action'),
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark
                              ? AppPalette.white.withValues(alpha: 0.5)
                              : AppPalette.black.withValues(alpha: 0.5),
                          foregroundColor:
                              isDark ? AppPalette.black : AppPalette.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          tr(context, config.action!),
                          style: Body2_b.style,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadedErrorPhoto extends StatelessWidget {
  const _FadedErrorPhoto({
    required this.asset,
    required this.background,
    required this.height,
  });

  final String asset;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.topCenter),
          IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('app-error-photo-fade'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    background.withValues(alpha: 0.8),
                    background,
                  ],
                  stops: const [0.0, 0.45, 0.82, 1.0],
                ),
              ),
            ),
          ),
        ],
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
    final hasPhoto = appErrorConfigFor(statusCode).imageAsset != null;
    return Scaffold(
      backgroundColor: hasPhoto
          ? AppColors.of(context).pageBackground
          : mainPageBackground(context),
      body: hasPhoto
          ? AppErrorView(statusCode: statusCode, onAction: _actionFor(context))
          : SafeArea(
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
