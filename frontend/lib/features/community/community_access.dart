import 'package:flutter/material.dart';
import 'package:onetouch/core/app_rule_notice.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class CommunityAccessBuilder extends StatelessWidget {
  const CommunityAccessBuilder({
    super.key,
    required this.teamId,
    required this.builder,
  });

  final int teamId;
  final Widget Function(BuildContext context, bool canParticipate) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: currentUserPreferences.favoriteTeamId,
        // 홈에서 조회 팀을 바꿔도 작성·좋아요 권한은 저장된 최애팀으로 판단해요.
        builder: (context, favoriteTeamId, _) =>
            builder(context, teamId == favoriteTeamId),
      );
}

class CommunityReadOnlyNotice extends StatefulWidget {
  const CommunityReadOnlyNotice({super.key});

  @override
  State<CommunityReadOnlyNotice> createState() =>
      _CommunityReadOnlyNoticeState();
}

class _CommunityReadOnlyNoticeState extends State<CommunityReadOnlyNotice> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) => _visible
      ? AppRuleNotice(
          key: const ValueKey('community-read-only-rule-notice'),
          message: tr(context,
              'You can post, comment and like only in your favorite team community.'),
          // 현재 방문에서만 숨기고, 커뮤니티 탭에 다시 들어오면 표시해요.
          onClose: () => setState(() => _visible = false),
        )
      : const SizedBox.shrink();
}
