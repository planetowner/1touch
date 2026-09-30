import 'package:flutter/foundation.dart';

@immutable
class GlobalNotificationPreferences {
  const GlobalNotificationPreferences({
    this.postReactions = true,
    this.postComments = true,
  });

  final bool postReactions;
  final bool postComments;

  GlobalNotificationPreferences copyWith({
    bool? postReactions,
    bool? postComments,
  }) =>
      GlobalNotificationPreferences(
        postReactions: postReactions ?? this.postReactions,
        postComments: postComments ?? this.postComments,
      );
}

@immutable
class TeamNotificationPreferences {
  const TeamNotificationPreferences({
    this.newBets = true,
    this.matchReminder = false,
    this.kickoff = true,
    this.halfTime = true,
    this.fullTime = true,
    this.goal = true,
    this.substitution = false,
  });

  final bool newBets;
  final bool matchReminder;
  final bool kickoff;
  final bool halfTime;
  final bool fullTime;
  final bool goal;
  final bool substitution;

  bool get allEnabled =>
      matchReminder && kickoff && halfTime && fullTime && goal && substitution;

  TeamNotificationPreferences copyWith({
    bool? newBets,
    bool? matchReminder,
    bool? kickoff,
    bool? halfTime,
    bool? fullTime,
    bool? goal,
    bool? substitution,
  }) =>
      TeamNotificationPreferences(
        newBets: newBets ?? this.newBets,
        matchReminder: matchReminder ?? this.matchReminder,
        kickoff: kickoff ?? this.kickoff,
        halfTime: halfTime ?? this.halfTime,
        fullTime: fullTime ?? this.fullTime,
        goal: goal ?? this.goal,
        substitution: substitution ?? this.substitution,
      );

  TeamNotificationPreferences setAll(bool enabled) =>
      TeamNotificationPreferences(
        newBets: enabled,
        matchReminder: enabled,
        kickoff: enabled,
        halfTime: enabled,
        fullTime: enabled,
        goal: enabled,
        substitution: enabled,
      );
}

@immutable
class PlayerNotificationPreferences {
  const PlayerNotificationPreferences({
    this.startingXi = true,
    this.substitute = true,
    this.goal = true,
    this.assist = true,
    this.yellowCard = false,
    this.redCard = false,
    this.injury = false,
  });

  final bool startingXi;
  final bool substitute;
  final bool goal;
  final bool assist;
  final bool yellowCard;
  final bool redCard;
  final bool injury;

  bool get allEnabled =>
      startingXi &&
      substitute &&
      goal &&
      assist &&
      yellowCard &&
      redCard &&
      injury;

  PlayerNotificationPreferences copyWith({
    bool? startingXi,
    bool? substitute,
    bool? goal,
    bool? assist,
    bool? yellowCard,
    bool? redCard,
    bool? injury,
  }) =>
      PlayerNotificationPreferences(
        startingXi: startingXi ?? this.startingXi,
        substitute: substitute ?? this.substitute,
        goal: goal ?? this.goal,
        assist: assist ?? this.assist,
        yellowCard: yellowCard ?? this.yellowCard,
        redCard: redCard ?? this.redCard,
        injury: injury ?? this.injury,
      );

  PlayerNotificationPreferences setAll(bool enabled) =>
      PlayerNotificationPreferences(
        startingXi: enabled,
        substitute: enabled,
        goal: enabled,
        assist: enabled,
        yellowCard: enabled,
        redCard: enabled,
        injury: enabled,
      );
}

@immutable
class NotificationPreferenceSnapshot {
  const NotificationPreferenceSnapshot({
    this.global = const GlobalNotificationPreferences(),
    this.teams = const {},
    this.players = const {},
  });

  final GlobalNotificationPreferences global;
  final Map<int, TeamNotificationPreferences> teams;
  final Map<int, PlayerNotificationPreferences> players;

  TeamNotificationPreferences team(int teamId) =>
      teams[teamId] ?? const TeamNotificationPreferences();

  PlayerNotificationPreferences player(int playerId) =>
      players[playerId] ?? const PlayerNotificationPreferences();
}
