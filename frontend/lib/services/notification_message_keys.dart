// 알림 종류와 메시지 키는 앱과 서버 내보내기에서 함께 써요. 번역은 messages.dart에 있어요.
const notificationMessageKeys = <String, ({String title, String body})>{
  "post_reaction": (title: "Community", body: "{author_name} liked your post."),
  "post_comment": (
    title: "Community",
    body: "{author_name}: {comment_preview}"
  ),
  "team_new_bets": (title: "Team update", body: "Betting is open for {match}."),
  "team_match_reminder": (
    title: "Team update",
    body: "{match} starts in {minutes_until_kickoff} minutes."
  ),
  "team_kickoff": (title: "Team update", body: "{match} — Kickoff!"),
  "team_half_time": (title: "Team update", body: "Half time · {match} {score}"),
  "team_full_time": (title: "Team update", body: "Full time · {match} {score}"),
  "team_goal": (
    title: "Team update",
    body: "⚽ {player} ({team}) {minute}' · {score}"
  ),
  "team_substitution": (
    title: "Team update",
    body: "{team} sub: {out_player} → {in_player} {minute}'"
  ),
  "player_starting_xi": (
    title: "Player update",
    body: "{player} is in the starting lineup."
  ),
  "player_substitute": (
    title: "Player update",
    body: "{player} comes on · {minute}'"
  ),
  "player_goal": (
    title: "Player update",
    body: "⚽ {player} scores · {minute}'"
  ),
  "player_assist": (
    title: "Player update",
    body: "{player} assists · {minute}'"
  ),
  "player_yellow_card": (
    title: "Player update",
    body: "{player} yellow card · {minute}'"
  ),
  "player_red_card": (
    title: "Player update",
    body: "{player} red card · {minute}'"
  ),
  "player_injury": (
    title: "Player update",
    body: "{player} substituted due to injury · {minute}'"
  ),
};
