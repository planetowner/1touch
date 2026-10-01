import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/community_ban.dart';

Future<bool?> showCommunityBanDialog(
  BuildContext context, {
  required CommunityBanStatus ban,
  DateTime Function()? now,
}) =>
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) =>
          _CommunityBanDialog(ban: ban, now: now ?? DateTime.now),
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
    // 종료 시각 전에 0초로 보이지 않도록 남은 시간을 올림해요.
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
    final reason = widget.ban.reason;
    const numberStyle = TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final unitStyle = numberStyle.copyWith(color: Colors.white54);
    return Dialog(
      key: const ValueKey('community-ban-dialog'),
      backgroundColor: const Color(0xFF3D3D3D),
      surfaceTintColor: Colors.transparent,
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
                tr(context, 'TEMPORARILY SUSPENDED'),
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
                // 사유는 문장 조각이에요. 언어별 연결 표현은 문장 틀에서 관리해요.
                reason == null
                    ? tr(context,
                        'Your access to the community has been restricted.')
                    : tr(
                        context,
                        'Your access to the community has been restricted for {reason}.',
                        {'reason': tr(context, reason.messageKey)},
                      ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context,
                    'You’ll be able to use the community again when the time above runs out.'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: TextButton(
                  key: const ValueKey('community-ban-close'),
                  // 닫기는 언제든 가능하지만 복귀 안내는 실제 만료 후에만 열어요.
                  onPressed: () => Navigator.of(context).pop(_secondsLeft == 0),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF090A0A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(tr(context, 'Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
