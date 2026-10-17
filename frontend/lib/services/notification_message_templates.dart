import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/services/notification_message_keys.dart';

enum DeviceNotificationCategory { team, player, posts, betting }

enum NotificationDeliveryTiming { eventDriven, thirtyMinutesBeforeKickoff }

/// Notification rows approved for both iOS and Android.
///
/// Spreadsheet rows 1 (team news), 17 (new post from following), and 19
/// (post-match betting result) are intentionally excluded.
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
  bettingNewBet(18, DeviceNotificationCategory.betting);

  const NotificationEventType(
    this.spreadsheetNumber,
    this.category, [
    this.deliveryTiming = NotificationDeliveryTiming.eventDriven,
  ]);

  final int spreadsheetNumber;
  final DeviceNotificationCategory category;
  final NotificationDeliveryTiming deliveryTiming;

  String get kind => switch (this) {
        NotificationEventType.teamMatchReminder => 'team_match_reminder',
        NotificationEventType.teamKickoff => 'team_kickoff',
        NotificationEventType.teamHalfTime => 'team_half_time',
        NotificationEventType.teamFullTime => 'team_full_time',
        NotificationEventType.teamGoal => 'team_goal',
        NotificationEventType.teamSubstitution => 'team_substitution',
        NotificationEventType.playerStartingXi => 'player_starting_xi',
        NotificationEventType.playerSubstitute => 'player_substitute',
        NotificationEventType.playerGoal => 'player_goal',
        NotificationEventType.playerAssist => 'player_assist',
        NotificationEventType.playerYellowCard => 'player_yellow_card',
        NotificationEventType.playerRedCard => 'player_red_card',
        NotificationEventType.playerInjury => 'player_injury',
        NotificationEventType.postReaction => 'post_reaction',
        NotificationEventType.postComment => 'post_comment',
        NotificationEventType.bettingNewBet => 'team_new_bets',
      };
}

class NotificationTemplateData {
  const NotificationTemplateData({
    this.team = '',
    this.opponent = '',
    this.homeTeam = '',
    this.awayTeam = '',
    this.player = '',
    this.substitutions = const [],
    this.displayName = '',
    this.commentPreview = '',
    this.minute = '',
    this.score = '',
    this.goalAgainst = false,
    this.minutesUntilKickoff = 30,
  });

  final String team;
  final String opponent;
  final String homeTeam;
  final String awayTeam;
  final String player;
  final List<({String outPlayer, String inPlayer})> substitutions;
  final String displayName;
  final String commentPreview;
  final String minute;
  final String score;
  final bool goalAgainst;
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
    final template = type == NotificationEventType.teamGoal && data.goalAgainst
        ? 'team_goal_against'
        : type.kind;
    final keys = notificationMessageKeys[template]!;
    final arguments = <String, Object>{
      'team': data.team,
      'opponent': data.opponent,
      'player': data.player,
      'count': data.substitutions.length,
      'substitutions': data.substitutions
          .map((item) => '${item.outPlayer} → ${item.inPlayer}')
          .join('\n'),
      'display_name': data.displayName,
      'comment_preview': _preview(data.commentPreview),
      'minute': data.minute,
      'score_line': '${data.homeTeam} ${data.score} ${data.awayTeam}',
      'minutes_until_kickoff': data.minutesUntilKickoff,
    };
    return DeviceNotificationMessage(
      type: type,
      title: translateMessage(locale, keys.title, arguments),
      body: translateMessage(locale, keys.body, arguments),
      payload: payload,
    );
  }

  static String _preview(String value) =>
      value.length <= 60 ? value : '${value.substring(0, 60)}…';
}
