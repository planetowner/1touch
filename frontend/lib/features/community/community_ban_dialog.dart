import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// Presentation input until the backend exposes a user-facing ban status.
class CommunityBanStatus {
  const CommunityBanStatus({required this.username, required this.endsAt});

  final String username;
  final DateTime endsAt;
}

Future<bool?> showCommunityBanDialog(
  BuildContext context, {
  required CommunityBanStatus ban,
  DateTime Function()? now,
}) =>
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: _CommunityBanDialog(ban: ban, now: now ?? DateTime.now),
      ),
    );

class _CommunityBanDialog extends StatefulWidget {
  const _CommunityBanDialog({required this.ban, required this.now});

  final CommunityBanStatus ban;
  final DateTime Function() now;

  @override
  State<_CommunityBanDialog> createState() => _CommunityBanDialogState();
}

class _CommunityBanDialogState extends State<_CommunityBanDialog> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft == 0) {
        _timer.cancel();
      }
      setState(() {});
    });
  }

  int get _secondsLeft {
    final milliseconds =
        widget.ban.endsAt.difference(widget.now()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _secondsLeft;
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    final seconds = remaining % 60;
    const numberStyle = TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final unitStyle = numberStyle.copyWith(color: Colors.white54);
    final greeting = tr(
      context,
      'Sorry, {username}. Your community access is suspended for',
    ).replaceAll('{username}', widget.ban.username);

    return Dialog(
      key: const ValueKey('community-ban-dialog'),
      backgroundColor: const Color(0xFF3D3D3D),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 345),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('community-ban-countdown'),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF272828),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: hours.toString().padLeft(2, '0'),
                          style: numberStyle),
                      TextSpan(text: 'h ', style: unitStyle),
                      TextSpan(
                          text: minutes.toString().padLeft(2, '0'),
                          style: numberStyle),
                      TextSpan(text: 'm ', style: unitStyle),
                      TextSpan(
                          text: seconds.toString().padLeft(2, '0'),
                          style: numberStyle),
                      TextSpan(text: 's', style: unitStyle),
                    ]),
                    key: const ValueKey('community-ban-time'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(context, 'due to [ban reason].'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'Please try again after the suspension ends.'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: TextButton(
                  key: const ValueKey('community-ban-understand'),
                  onPressed: remaining == 0
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white38,
                    foregroundColor: const Color(0xFF090A0A),
                    disabledForegroundColor: const Color(0xFF090A0A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(tr(context, 'I UNDERSTAND!')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
