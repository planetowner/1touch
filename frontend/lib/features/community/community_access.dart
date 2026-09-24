import 'package:flutter/material.dart';
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

class CommunityReadOnlyNotice extends StatelessWidget {
  const CommunityReadOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          tr(context,
              'You can post, comment and like only in your favorite team community.'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}
