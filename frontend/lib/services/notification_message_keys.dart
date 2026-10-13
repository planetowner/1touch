// 알림 종류와 메시지 키는 앱과 서버 내보내기에서 함께 써요. 번역은 messages.dart에 있어요.
const notificationMessageKeys = <String, ({String title, String body})>{
  "post_reaction": (
    title: "Your post",
    body: "{display_name} liked your post."
  ),
  "post_comment": (
    title: "New comment on your post",
    body: "{display_name}: {comment_preview}"
  ),
  "team_new_bets": (title: "{team}", body: "Betting is open vs {opponent}."),
  "team_match_reminder": (
    title: "{team}",
    body: "Kickoff vs {opponent} in {minutes_until_kickoff} min."
  ),
  "team_kickoff": (title: "{team}", body: "Kickoff vs {opponent}."),
  "team_half_time": (title: "{team}", body: "Half time · {score_line}"),
  "team_full_time": (title: "{team}", body: "Full time · {score_line}"),
  "team_goal": (
    title: "{team}",
    body: "⚽ Goal! {player} {minute}’ · {score_line}"
  ),
  // 같은 골 이벤트를 받는 팀에 따라 득점·실점 문구만 나눠요.
  "team_goal_against": (
    title: "{team}",
    body: "Conceded · {player} {minute}’ · {score_line}"
  ),
  "team_substitution": (
    title: "{team}",
    body: "Sub {minute}’ · {out_player} → {in_player}"
  ),
  "player_starting_xi": (title: "{player}", body: "Starting vs {opponent}."),
  "player_substitute": (
    title: "{player}",
    body: "On at {minute}’ vs {opponent}"
  ),
  "player_goal": (title: "{player}", body: "⚽ Goal! {minute}’ · {score_line}"),
  "player_assist": (
    title: "{player}",
    body: "🅰️ Assist {minute}’ · {score_line}"
  ),
  "player_yellow_card": (
    title: "{player}",
    body: "🟨 Yellow card {minute}’ vs {opponent}"
  ),
  "player_red_card": (
    title: "{player}",
    body: "🟥 Red card {minute}’ vs {opponent}"
  ),
  "player_injury": (
    title: "{player}",
    body: "Off injured {minute}’ vs {opponent}"
  ),
};
