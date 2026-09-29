import 'package:flutter/widgets.dart';

enum DeviceNotificationCategory { team, player, posts, betting }

enum NotificationDeliveryTiming { eventDriven, thirtyMinutesBeforeKickoff }

/// Notification rows approved for both iOS and Android.
///
/// Spreadsheet row 1 (team news) and row 17 (new post from following) are
/// intentionally excluded.
enum NotificationEventType {
  teamMatchReminder(
    2,
    DeviceNotificationCategory.team,
    NotificationDeliveryTiming.thirtyMinutesBeforeKickoff,
  ),
  teamKickoff(3, DeviceNotificationCategory.team),
  teamHalfTime(4, DeviceNotificationCategory.team),
  teamFullTime(5, DeviceNotificationCategory.team),
  teamGoal(6, DeviceNotificationCategory.team),
  teamSubstitution(7, DeviceNotificationCategory.team),
  playerStartingXi(8, DeviceNotificationCategory.player),
  playerSubstitute(9, DeviceNotificationCategory.player),
  playerGoal(10, DeviceNotificationCategory.player),
  playerAssist(11, DeviceNotificationCategory.player),
  playerYellowCard(12, DeviceNotificationCategory.player),
  playerRedCard(13, DeviceNotificationCategory.player),
  playerInjury(14, DeviceNotificationCategory.player),
  postReaction(15, DeviceNotificationCategory.posts),
  postComment(16, DeviceNotificationCategory.posts),
  bettingNewBet(18, DeviceNotificationCategory.betting),
  bettingPostMatchResult(19, DeviceNotificationCategory.betting);

  const NotificationEventType(
    this.spreadsheetNumber,
    this.category, [
    this.deliveryTiming = NotificationDeliveryTiming.eventDriven,
  ]);

  final int spreadsheetNumber;
  final DeviceNotificationCategory category;
  final NotificationDeliveryTiming deliveryTiming;
}

class NotificationTemplateData {
  const NotificationTemplateData({
    this.team = '',
    this.homeTeam = '',
    this.awayTeam = '',
    this.player = '',
    this.outPlayer = '',
    this.inPlayer = '',
    this.username = '',
    this.commentPreview = '',
    this.minute = '',
    this.score = '',
    this.result = '',
    this.betOutcome = '',
    this.minutesUntilKickoff = 30,
  });

  final String team;
  final String homeTeam;
  final String awayTeam;
  final String player;
  final String outPlayer;
  final String inPlayer;
  final String username;
  final String commentPreview;
  final String minute;
  final String score;
  final String result;
  final String betOutcome;
  final int minutesUntilKickoff;
}

class DeviceNotificationMessage {
  const DeviceNotificationMessage({
    required this.type,
    required this.title,
    required this.body,
    this.payload,
  });

  final NotificationEventType type;
  final String title;
  final String body;
  final String? payload;
}

class NotificationMessageTemplates {
  const NotificationMessageTemplates._();

  static DeviceNotificationMessage build({
    required NotificationEventType type,
    required Locale locale,
    required NotificationTemplateData data,
    String? payload,
  }) {
    final korean = locale.languageCode == 'ko';
    return DeviceNotificationMessage(
      type: type,
      title: _title(type.category, korean),
      body: _body(type, data, korean),
      payload: payload,
    );
  }

  static String _title(DeviceNotificationCategory category, bool korean) =>
      switch (category) {
        DeviceNotificationCategory.team => korean ? '팀 소식' : 'Team update',
        DeviceNotificationCategory.player => korean ? '선수 소식' : 'Player update',
        DeviceNotificationCategory.posts => korean ? '게시물' : 'Posts',
        DeviceNotificationCategory.betting => korean ? '베팅' : 'Betting',
      };

  static String _body(
    NotificationEventType type,
    NotificationTemplateData d,
    bool ko,
  ) =>
      switch (type) {
        NotificationEventType.teamMatchReminder => ko
            ? '${d.team} 경기가 ${d.minutesUntilKickoff}분 후에 시작됩니다.'
            : '${d.team} kicks off in ${d.minutesUntilKickoff} minutes.',
        NotificationEventType.teamKickoff => ko
            ? '${d.homeTeam} vs ${d.awayTeam} 경기가 시작되었습니다!'
            : '${d.homeTeam} vs ${d.awayTeam} — Kickoff!',
        NotificationEventType.teamHalfTime => ko
            ? '전반전 종료. ${d.homeTeam} ${d.score} ${d.awayTeam}'
            : 'Half Time: ${d.homeTeam} ${d.score} ${d.awayTeam}',
        NotificationEventType.teamFullTime => ko
            ? '경기 종료. ${d.homeTeam} ${d.score} ${d.awayTeam}'
            : 'Full Time: ${d.homeTeam} ${d.score} ${d.awayTeam}',
        NotificationEventType.teamGoal => ko
            ? "⚽ 골! ${d.player} (${d.team}) ${d.minute}' · ${d.score}"
            : "⚽ GOAL! ${d.player} (${d.team}) ${d.minute}' · ${d.score}",
        NotificationEventType.teamSubstitution => ko
            ? "${d.team} 교체: ${d.outPlayer} → ${d.inPlayer} ${d.minute}'"
            : "${d.team} Sub: ${d.outPlayer} → ${d.inPlayer} ${d.minute}'",
        NotificationEventType.playerStartingXi => ko
            ? '${d.player}이(가) 오늘 경기 선발 출전합니다.'
            : '${d.player} is in the starting lineup today.',
        NotificationEventType.playerSubstitute => ko
            ? "${d.player}이(가) ${d.minute}'에 교체 투입되었습니다."
            : "${d.player} has come on as a substitute (${d.minute}').",
        NotificationEventType.playerGoal => ko
            ? "⚽ ${d.player} 골! ${d.minute}' (${d.team})"
            : "⚽ ${d.player} scores! ${d.minute}' (${d.team})",
        NotificationEventType.playerAssist => ko
            ? "🎯 ${d.player} 어시스트! ${d.minute}' (${d.team})"
            : "🎯 ${d.player} with the assist! ${d.minute}' (${d.team})",
        NotificationEventType.playerYellowCard => ko
            ? "🟨 ${d.player} 경고 카드 ${d.minute}' (${d.team})"
            : "🟨 ${d.player} receives a yellow card ${d.minute}' (${d.team})",
        NotificationEventType.playerRedCard => ko
            ? "🟥 ${d.player} 퇴장! ${d.minute}' (${d.team})"
            : "🟥 ${d.player} is sent off! ${d.minute}' (${d.team})",
        NotificationEventType.playerInjury => ko
            ? "${d.player}이(가) 부상으로 교체되었습니다. ${d.minute}'"
            : "${d.player} has been substituted due to injury. ${d.minute}'",
        NotificationEventType.postReaction => ko
            ? '${d.username}님이 회원님의 게시물에 반응했습니다.'
            : '${d.username} reacted to your post.',
        NotificationEventType.postComment => ko
            ? '${d.username}: ${_preview(d.commentPreview)}'
            : '${d.username}: ${_preview(d.commentPreview)}',
        NotificationEventType.bettingNewBet => ko
            ? '새로운 베팅이 등록되었습니다. 지금 확인하세요!'
            : 'A new bet is now available. Check it out!',
        NotificationEventType.bettingPostMatchResult => ko
            ? '베팅 결과: ${d.team} ${d.result}. ${d.betOutcome}'
            : 'Bet result: ${d.team} ${d.result}. ${d.betOutcome}',
      };

  static String _preview(String value) =>
      value.length <= 60 ? value : '${value.substring(0, 60)}…';
}
