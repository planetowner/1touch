// 화면 문구는 네 언어에서 같은 키로 관리해요.
typedef MessageTranslations = ({String ko, String ja, String zh});

// 다른 화면과 키가 같아도 팀 화면에서는 이 한국어 문구를 써요.
const teamScreenKoreanMessages = <String, String>{
  'Overview': '팀 정보',
  'Matches': '일정',
  'STANDING': '리그 순위',
};

const appMessages = <String, MessageTranslations>{
  "Team updates": (ko: "팀 소식", ja: "チーム情報", zh: "球队动态"),
  "Match and score updates for followed teams.": (
    ko: "팔로우한 팀의 경기와 점수 소식이에요.",
    ja: "フォロー中のチームの試合・スコア情報です。",
    zh: "关注球队的比赛和比分动态。"
  ),
  "Player updates": (ko: "선수 소식", ja: "選手情報", zh: "球员动态"),
  "Match events for followed players.": (
    ko: "팔로우한 선수의 경기 소식이에요.",
    ja: "フォロー中の選手の試合情報です。",
    zh: "关注球员的比赛动态。"
  ),
  "Post updates": (ko: "게시물 소식", ja: "投稿への反応", zh: "帖子动态"),
  "Reactions and comments on your posts.": (
    ko: "내 게시물에 달린 좋아요와 댓글이에요.",
    ja: "あなたの投稿へのいいねやコメントです。",
    zh: "你的帖子收到的点赞和评论。"
  ),
  "Betting updates": (ko: "베팅 소식", ja: "予想のお知らせ", zh: "竞猜动态"),
  "New bets and settled result updates.": (
    ko: "새로운 베팅과 결과 소식이에요.",
    ja: "新しい予想の受付と結果のお知らせです。",
    zh: "新竞猜及结算结果动态。"
  ),
  "Team update": (ko: "팀 소식", ja: "チーム情報", zh: "球队动态"),
  "Player update": (ko: "선수 소식", ja: "選手情報", zh: "球员动态"),
  "{author_name} liked your post.": (
    ko: "{author_name}님이 내 게시물에 좋아요를 눌렀어요.",
    ja: "{author_name}さんがあなたの投稿にいいねしました。",
    zh: "{author_name}赞了你的帖子。"
  ),
  "{author_name}: {comment_preview}": (
    ko: "{author_name}: {comment_preview}",
    ja: "{author_name}: {comment_preview}",
    zh: "{author_name}: {comment_preview}"
  ),
  "Betting is open for {match}.": (
    ko: "{match} 베팅이 열렸어요.",
    ja: "{match}の予想受付が始まりました。",
    zh: "{match}的竞猜已开放。"
  ),
  "{match} starts in {minutes_until_kickoff} minutes.": (
    ko: "{match} 경기가 {minutes_until_kickoff}분 후 시작해요.",
    ja: "{match}は{minutes_until_kickoff}分後にキックオフです。",
    zh: "{match}将在{minutes_until_kickoff}分钟后开始。"
  ),
  "{match} — Kickoff!": (
    ko: "{match} 경기가 시작했어요.",
    ja: "{match} — キックオフ！",
    zh: "{match} — 比赛开始！"
  ),
  "Half time · {match} {score}": (
    ko: "전반 종료 · {match} {score}",
    ja: "前半終了 · {match} {score}",
    zh: "上半场结束 · {match} {score}"
  ),
  "Full time · {match} {score}": (
    ko: "경기 종료 · {match} {score}",
    ja: "試合終了 · {match} {score}",
    zh: "全场结束 · {match} {score}"
  ),
  "⚽ {player} ({team}) {minute}' · {score}": (
    ko: "⚽ {player} ({team}) {minute}' · {score}",
    ja: "⚽ {player} ({team}) {minute}' · {score}",
    zh: "⚽ {player} ({team}) {minute}' · {score}"
  ),
  "{team} sub: {out_player} → {in_player} {minute}'": (
    ko: "{team} 교체: {out_player} → {in_player} {minute}'",
    ja: "{team} 交代: {out_player} → {in_player} {minute}'",
    zh: "{team}换人: {out_player} → {in_player} {minute}'"
  ),
  "{player} is in the starting lineup.": (
    ko: "{player} 선발 출전이 확정됐어요.",
    ja: "{player}のスタメン出場が決まりました。",
    zh: "{player}确认首发出场。"
  ),
  "{player} comes on · {minute}'": (
    ko: "{player} 교체 투입 · {minute}'",
    ja: "{player}が途中出場 · {minute}'",
    zh: "{player}替补登场 · {minute}'"
  ),
  "⚽ {player} scores · {minute}'": (
    ko: "⚽ {player} 골 · {minute}'",
    ja: "⚽ {player}がゴール · {minute}'",
    zh: "⚽ {player}进球 · {minute}'"
  ),
  "{player} assists · {minute}'": (
    ko: "{player} 도움 · {minute}'",
    ja: "{player}がアシスト · {minute}'",
    zh: "{player}助攻 · {minute}'"
  ),
  "{player} yellow card · {minute}'": (
    ko: "{player} 경고 · {minute}'",
    ja: "{player}にイエローカード · {minute}'",
    zh: "{player}领到黄牌 · {minute}'"
  ),
  "{player} red card · {minute}'": (
    ko: "{player} 퇴장 · {minute}'",
    ja: "{player}にレッドカード · {minute}'",
    zh: "{player}领到红牌 · {minute}'"
  ),
  "{player} substituted due to injury · {minute}'": (
    ko: "{player} 부상으로 교체 · {minute}'",
    ja: "{player}が負傷交代 · {minute}'",
    zh: "{player}因伤被换下 · {minute}'"
  ),
  "Open live match": (ko: "라이브 경기 보기", ja: "ライブ試合を見る", zh: "查看直播比赛"),
  "You won {points} points!": (
    ko: "{points}포인트를 획득했어요!",
    ja: "{points}ポイント獲得しました！",
    zh: "你赢得了{points}积分！"
  ),
  "{points} points returned": (
    ko: "{points}포인트가 반환됐어요",
    ja: "{points}ポイントが返還されました",
    zh: "已返还{points}积分"
  ),
  "Your bet on {team} was correct.": (
    ko: "{team}에 대한 베팅이 적중했어요.",
    ja: "{team}への予想が的中しました。",
    zh: "你对{team}的预测正确。"
  ),
  "Your bet on {team} was not correct.": (
    ko: "{team}에 대한 베팅이 적중하지 않았어요.",
    ja: "{team}への予想は的中しませんでした。",
    zh: "你对{team}的预测未命中。"
  ),
  "Your bet on {team} was refunded.": (
    ko: "{team}에 대한 베팅 포인트가 반환됐어요.",
    ja: "{team}への予想ポイントが返還されました。",
    zh: "你对{team}的投注积分已返还。"
  ),
  "SEE RESULTS": (ko: "결과 보기", ja: "結果を見る", zh: "查看结果"),
  "MAYBE LATER": (ko: "나중에 보기", ja: "あとで見る", zh: "稍后查看"),
  "Email or username": (ko: "이메일 또는 아이디", ja: "メールアドレスまたはユーザー名", zh: "邮箱或用户名"),
  "Forgot password?": (ko: "비밀번호를 잊으셨나요?", ja: "パスワードをお忘れですか？", zh: "忘记密码？"),
  "Don't have an account?": (
    ko: "계정이 없으신가요?",
    ja: "アカウントをお持ちでないですか？",
    zh: "还没有账号？"
  ),
  "Enter your email or username and password.": (
    ko: "이메일 또는 아이디와 비밀번호를 입력해 주세요.",
    ja: "メールアドレスまたはユーザー名とパスワードを入力してください。",
    zh: "请输入邮箱或用户名及密码。"
  ),
  "Unable to sign in. Check your email or username and password.": (
    ko: "로그인하지 못했어요. 이메일 또는 아이디와 비밀번호를 확인해 주세요.",
    ja: "ログインできませんでした。メールアドレスまたはユーザー名とパスワードを確認してください。",
    zh: "登录失败，请检查邮箱或用户名及密码。"
  ),
  "Reset password": (ko: "비밀번호 재설정", ja: "パスワードの再設定", zh: "重置密码"),
  "Enter the email linked to your account. We will send you a verification code to reset your password.":
      (
    ko: "이 계정과 연결된 이메일을 입력해 주세요. 비밀번호 재설정을 위한 인증번호를 보내드릴게요.",
    ja: "アカウントに登録したメールアドレスを入力してください。パスワード再設定用の認証コードを送信します。",
    zh: "请输入此账户关联的邮箱。我们将发送密码重置验证码。"
  ),
  "Enter the verification code sent to your email.": (
    ko: "이메일로 받은 인증번호를 입력해 주세요.",
    ja: "メールで届いた認証コードを入力してください。",
    zh: "请输入发送到邮箱的验证码。"
  ),
  "Enter a new password.": (
    ko: "새로운 비밀번호를 입력해 주세요.",
    ja: "新しいパスワードを入力してください。",
    zh: "请输入新密码。"
  ),
  "Enter it again.": (ko: "다시 입력해 주세요.", ja: "もう一度入力してください。", zh: "请再次输入。"),
  "Passwords do not match.": (
    ko: "비밀번호가 일치하지 않아요.",
    ja: "パスワードが一致しません。",
    zh: "两次输入的密码不一致。"
  ),
  "Please check the highlighted fields.": (
    ko: "표시된 입력 내용을 확인해 주세요.",
    ja: "表示された入力項目を確認してください。",
    zh: "请检查标记的输入项。"
  ),
  "Please agree to the Terms and Privacy Policy.": (
    ko: "이용약관과 개인정보 처리방침에 동의해 주세요.",
    ja: "利用規約とプライバシーポリシーに同意してください。",
    zh: "请同意条款和隐私政策。"
  ),
  "Retype Password": (ko: "비밀번호 다시 입력", ja: "パスワードを再入力", zh: "再次输入密码"),
  "Choose a password that is 8 or more characters long.": (
    ko: "비밀번호는 8자 이상으로 설정해 주세요.",
    ja: "パスワードは8文字以上で設定してください。",
    zh: "密码长度至少为8个字符。"
  ),
  "Invalid verification code. Try again.": (
    ko: "인증번호가 올바르지 않아요. 다시 입력해 주세요.",
    ja: "認証コードが正しくありません。もう一度お試しください。",
    zh: "验证码无效，请重试。"
  ),
  "New password": (ko: "새 비밀번호", ja: "新しいパスワード", zh: "新密码"),
  "Enter the email address you used to sign up.": (
    ko: "가입할 때 사용한 이메일을 입력해 주세요.",
    ja: "登録時に使用したメールアドレスを入力してください。",
    zh: "请输入注册时使用的邮箱。"
  ),
  "Send verification code": (ko: "인증번호 보내기", ja: "認証コードを送信", zh: "发送验证码"),
  "Use 8–128 characters with uppercase and lowercase English letters and a number.":
      (
    ko: "영문 대문자·소문자와 숫자를 포함해 8~128자로 입력해 주세요.",
    ja: "英大文字・小文字と数字を含む8〜128文字で入力してください。",
    zh: "请输入8至128个字符，包含英文大写字母、小写字母和数字。"
  ),
  "Password reset. Sign in with your new password.": (
    ko: "비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요.",
    ja: "パスワードを再設定しました。新しいパスワードでログインしてください。",
    zh: "密码已重置，请使用新密码登录。"
  ),
  "Unable to reset your password. Please try again.": (
    ko: "비밀번호를 바꾸지 못했어요. 다시 시도해 주세요.",
    ja: "パスワードを再設定できませんでした。もう一度お試しください。",
    zh: "无法重置密码，请重试。"
  ),
  "Continue with Google": (
    ko: "Google로 계속하기",
    ja: "Googleで続ける",
    zh: "使用 Google 继续"
  ),
  "Continue with Apple": (
    ko: "Apple로 계속하기",
    ja: "Appleで続ける",
    zh: "使用 Apple 继续"
  ),
  "Continue with Kakao": (ko: "카카오로 계속하기", ja: "Kakaoで続ける", zh: "使用 Kakao 继续"),
  "Continue with LINE": (ko: "LINE으로 계속하기", ja: "LINEで続ける", zh: "使用 LINE 继续"),
  "Continue with email": (ko: "이메일로 계속하기", ja: "メールで続ける", zh: "使用邮箱继续"),
  "Other login methods": (ko: "다른 로그인 방법", ja: "その他のログイン方法", zh: "其他登录方式"),
  "Unable to load login methods. Please try again.": (
    ko: "로그인 방법을 불러오지 못했어요. 다시 시도해 주세요.",
    ja: "ログイン方法を読み込めませんでした。もう一度お試しください。",
    zh: "无法加载登录方式，请重试。"
  ),
  "Unable to sign in with {provider}. Please try again.": (
    ko: "{provider} 로그인에 실패했어요. 다시 시도해 주세요.",
    ja: "{provider}でログインできませんでした。もう一度お試しください。",
    zh: "无法使用{provider}登录，请重试。"
  ),
  "Unable to sign in with Google. Please try again.": (
    ko: "Google 로그인에 실패했어요. 다시 시도해 주세요.",
    ja: "Googleでログインできませんでした。もう一度お試しください。",
    zh: "无法使用 Google 登录，请重试。"
  ),
  "Sign in": (ko: "로그인", ja: "ログイン", zh: "登录"),
  "Sign up": (ko: "회원가입", ja: "新規登録", zh: "注册"),
  "SIGN IN": (ko: "로그인", ja: "ログイン", zh: "登录"),
  "SIGN UP": (ko: "회원가입", ja: "新規登録", zh: "注册"),
  "LOGIN": (ko: "로그인", ja: "ログイン", zh: "登录"),
  "Username": (ko: "아이디", ja: "ユーザー名", zh: "用户名"),
  "Nickname": (ko: "닉네임", ja: "ニックネーム", zh: "昵称"),
  "Pick a nickname": (ko: "닉네임 정하기", ja: "ニックネームを決める", zh: "选择昵称"),
  "Unable to save your profile. Please try again.": (
    ko: "프로필을 저장하지 못했어요. 다시 시도해 주세요.",
    ja: "プロフィールを保存できませんでした。もう一度お試しください。",
    zh: "无法保存个人资料，请重试。"
  ),
  "Checking availability...": (
    ko: "사용할 수 있는지 확인하고 있어요.",
    ja: "使用できるか確認しています。",
    zh: "正在检查是否可用。"
  ),
  "Available.": (ko: "사용할 수 있어요.", ja: "使用できます。", zh: "可以使用。"),
  "Already in use.": (
    ko: "이미 사용 중이에요. 다른 값을 입력해 주세요.",
    ja: "既に使用されています。別の値を入力してください。",
    zh: "已被使用，请输入其他内容。"
  ),
  "Unable to check availability. Try again.": (
    ko: "중복 여부를 확인하지 못했어요. 다시 시도해 주세요.",
    ja: "使用できるか確認できませんでした。もう一度お試しください。",
    zh: "无法检查是否可用，请重试。"
  ),
  "Favorite team": (ko: "최애팀", ja: "お気に入りのチーム", zh: "最喜欢的球队"),
  "Enter nickname": (ko: "닉네임을 입력해 주세요", ja: "ニックネームを入力してください", zh: "请输入昵称"),
  "Use 1–30 English letters, numbers, underscores, or dots. Dots cannot be first, last, or consecutive.":
      (
    ko: "아이디는 영문, 숫자, 밑줄(_), 마침표(.)로 1~30자 입력해 주세요. 마침표는 맨 앞·뒤나 연속으로 쓸 수 없어요.",
    ja: "ユーザー名は英数字、アンダースコア、ピリオドで1～30文字にしてください。ピリオドは先頭・末尾・連続で使えません。",
    zh: "用户名须为1～30位英文字母、数字、下划线或句点。句点不能在开头、结尾或连续使用。"
  ),
  "Use Korean syllables, English letters, or numbers only (4–12 units; Korean counts as 2).":
      (
    ko: "닉네임은 완성형 한글, 영문, 숫자만 쓸 수 있어요. 한글은 2단위, 영문·숫자는 1단위로 세어 총 4~12단위로 입력해 주세요.",
    ja: "ニックネームはハングル音節、英数字のみ使用できます。ハングルを2、英数字を1として4～12単位にしてください。",
    zh: "昵称只能使用完整韩文字、英文字母和数字。韩文字计2，英文字母和数字计1，总计须为4～12。"
  ),
  "Username or nickname is already in use": (
    ko: "이미 사용 중인 아이디 또는 닉네임이에요.",
    ja: "そのユーザー名またはニックネームは既に使用されています。",
    zh: "该用户名或昵称已被使用。"
  ),
  "Email, username, or nickname is already registered": (
    ko: "이미 등록된 이메일, 아이디 또는 닉네임이에요.",
    ja: "そのメールアドレス、ユーザー名、またはニックネームは既に登録されています。",
    zh: "该邮箱、用户名或昵称已被注册。"
  ),
  "You can change {item} up to {count} times in {days} days. Try again after {date}.":
      (
    ko: "{item}은 {days}일 동안 {count}번까지 바꿀 수 있어요. {date} 이후 다시 시도해 주세요.",
    ja: "{item}は{days}日間に{count}回まで変更できます。{date}以降に再試行してください。",
    zh: "{item}在{days}天内最多可修改{count}次。请在{date}之后重试。"
  ),
  "Password": (ko: "비밀번호", ja: "パスワード", zh: "密码"),
  "Email": (ko: "이메일", ja: "メールアドレス", zh: "邮箱"),
  "EMAIL": (ko: "이메일", ja: "メール", zh: "邮箱"),
  "First name": (ko: "이름", ja: "名", zh: "名字"),
  "Last name": (ko: "성", ja: "姓", zh: "姓氏"),
  "Enter first name": (ko: "이름을 입력해 주세요", ja: "名を入力してください", zh: "请输入名字"),
  "Enter last name": (ko: "성을 입력해 주세요", ja: "姓を入力してください", zh: "请输入姓氏"),
  "Enter username": (ko: "아이디를 입력해 주세요", ja: "ユーザー名を入力してください", zh: "请输入用户名"),
  "Enter email": (ko: "이메일을 입력해 주세요", ja: "メールアドレスを入力してください", zh: "请输入邮箱"),
  "Enter a valid email": (
    ko: "올바른 이메일을 입력해 주세요",
    ja: "有効なメールアドレスを入力してください",
    zh: "请输入有效的邮箱"
  ),
  "At least 8 characters": (
    ko: "8자 이상 입력해 주세요",
    ja: "8文字以上で入力してください",
    zh: "请输入至少8个字符"
  ),
  "Remember me": (ko: "로그인 정보 기억하기", ja: "ログイン情報を保存", zh: "记住我"),
  "Need sign up?": (ko: "아직 회원이 아니신가요?", ja: "アカウントをお持ちでない方", zh: "还没有账号？"),
  "Unable to sign in. Check your username and password.": (
    ko: "로그인하지 못했어요. 유저네임과 비밀번호를 확인해 주세요.",
    ja: "ログインできませんでした。ユーザー名とパスワードを確認してください。",
    zh: "登录失败，请检查用户名和密码。"
  ),
  "Verify your email": (ko: "이메일 인증", ja: "メールアドレスの確認", zh: "验证邮箱"),
  "Verification code": (ko: "인증번호", ja: "認証コード", zh: "验证码"),
  "Enter the 6-digit code.": (
    ko: "6자리 인증번호를 입력해 주세요.",
    ja: "6桁の認証コードを入力してください。",
    zh: "请输入6位验证码。"
  ),
  "Enter the verification code that we sent to ": (
    ko: "인증번호를 보낸 이메일: ",
    ja: "認証コードの送信先：",
    zh: "验证码已发送至："
  ),
  "Didn't get code? ": (
    ko: "인증번호를 받지 못하셨나요? ",
    ja: "コードが届きませんか？ ",
    zh: "没有收到验证码？"
  ),
  "Send again": (ko: "다시 보내기", ja: "再送信", zh: "重新发送"),
  "Sending...": (ko: "보내는 중…", ja: "送信中…", zh: "发送中…"),
  "Code expired": (ko: "인증번호가 만료됐어요", ja: "認証コードの有効期限が切れました", zh: "验证码已过期"),
  "Code expires in {time}": (
    ko: "인증번호 만료까지 {time}",
    ja: "有効期限まで {time}",
    zh: "验证码将在 {time} 后过期"
  ),
  "Send again ({seconds}s)": (
    ko: "{seconds}초 후 다시 보내기",
    ja: "{seconds}秒後に再送信",
    zh: "{seconds}秒后重新发送"
  ),
  "A new verification code was sent.": (
    ko: "새 인증번호를 보냈어요.",
    ja: "新しい認証コードを送信しました。",
    zh: "已发送新的验证码。"
  ),
  "This code has expired. Send a new code.": (
    ko: "인증번호가 만료됐어요. 새 인증번호를 받아 주세요.",
    ja: "コードの有効期限が切れました。再送信してください。",
    zh: "验证码已过期，请重新获取。"
  ),
  "Restart signup to request a new verification code.": (
    ko: "회원가입을 다시 시작해 새 인증번호를 받아 주세요.",
    ja: "新規登録をやり直して認証コードを取得してください。",
    zh: "请重新注册以获取新的验证码。"
  ),
  "Unable to send a verification code. Check your connection and try again.": (
    ko: "인증번호를 보내지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.",
    ja: "認証コードを送信できませんでした。接続を確認して再度お試しください。",
    zh: "无法发送验证码，请检查网络连接后重试。"
  ),
  "Unable to resend the code. Check your connection and try again.": (
    ko: "인증번호를 다시 보내지 못했어요. 연결 상태를 확인해 주세요.",
    ja: "コードを再送信できませんでした。接続を確認してください。",
    zh: "无法重新发送验证码，请检查网络连接。"
  ),
  "Unable to verify the code. Check your connection and try again.": (
    ko: "인증번호를 확인하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.",
    ja: "コードを確認できませんでした。接続を確認して再度お試しください。",
    zh: "无法验证验证码，请检查网络连接后重试。"
  ),
  "Complete your profile": (
    ko: "프로필을 완성해 주세요",
    ja: "プロフィールを完成させましょう",
    zh: "完善个人资料"
  ),
  "Save profile": (ko: "프로필 저장", ja: "プロフィールを保存", zh: "保存个人资料"),
  "Saving…": (ko: "저장 중…", ja: "保存中…", zh: "保存中…"),
  "Unable to save profile. Check your username and try again.": (
    ko: "프로필을 저장하지 못했어요. 유저네임을 확인하고 다시 시도해 주세요.",
    ja: "プロフィールを保存できませんでした。ユーザー名を確認して再度お試しください。",
    zh: "无法保存个人资料，请检查用户名后重试。"
  ),
  "Unable to load your account. Please try again.": (
    ko: "계정 정보를 불러오지 못했어요. 다시 시도해 주세요.",
    ja: "アカウントを読み込めませんでした。もう一度お試しください。",
    zh: "无法加载账号信息，请重试。"
  ),
  "Welcome to 1touch!": (
    ko: "1touch에 오신 걸 환영해요!",
    ja: "1touchへようこそ！",
    zh: "欢迎来到1touch！"
  ),
  "Let’s start by choosing\nyour favorite teams!": (
    ko: "먼저 좋아하는 팀을\n선택해 주세요!",
    ja: "まずはお気に入りのチームを\n選びましょう！",
    zh: "先选择你喜欢的\n球队吧！"
  ),
  "Your setup is complete. Let’s see what\nyour favorites are up to.": (
    ko: "설정이 끝났어요. 이제 좋아하는 팀의\n소식을 만나보세요.",
    ja: "設定が完了しました。お気に入りの\nチームの情報をチェックしましょう。",
    zh: "设置完成，看看你喜欢的\n球队有什么新动态吧。"
  ),
  "Select your favorite club(s)": (
    ko: "좋아하는 팀을 선택해 주세요",
    ja: "お気に入りのクラブを選択",
    zh: "选择你喜欢的俱乐部"
  ),
  "You may choose up to 1 team per league": (
    ko: "리그마다 한 팀씩 선택할 수 있어요",
    ja: "各リーグから1チームずつ選べます",
    zh: "每个联赛最多选择一支球队"
  ),
  "Rank your clubs": (
    ko: "좋아하는 팀의 순서를 정해 주세요",
    ja: "クラブの優先順位を決めましょう",
    zh: "为你喜欢的俱乐部排序"
  ),
  "Hold and drag a team card up or down to reorder your favorites. Don't worry, you can always change this later.":
      (
    ko: "팀 카드를 길게 눌러 위아래로 옮겨 주세요. 순서는 나중에도 바꿀 수 있어요.",
    ja: "チームのカードを長押しして上下に動かしてください。順番は後から変更できます。",
    zh: "长按并上下拖动球队卡片来调整顺序，之后也可以随时更改。"
  ),
  "Back to team selection": (ko: "팀 선택으로 돌아가기", ja: "チーム選択に戻る", zh: "返回球队选择"),
  "Continue": (ko: "계속하기", ja: "続ける", zh: "继续"),
  "CONTINUE": (ko: "계속하기", ja: "続ける", zh: "继续"),
  "FINISH": (ko: "완료", ja: "完了", zh: "完成"),
  "Home": (ko: "홈", ja: "ホーム", zh: "首页"),
  "Players": (ko: "선수", ja: "選手", zh: "球员"),
  "Community": (ko: "커뮤니티", ja: "コミュニティ", zh: "社区"),
  "MY TEAM": (ko: "현재 팀", ja: "マイチーム", zh: "我的球队"),
  "PLAYER": (ko: "선수", ja: "選手", zh: "球员"),
  "PLAYERS": (ko: "선수", ja: "選手", zh: "球员"),
  "TEAM": (ko: "팀", ja: "チーム", zh: "球队"),
  "TEAMS": (ko: "팀", ja: "チーム", zh: "球队"),
  "POSTS": (ko: "게시글", ja: "投稿", zh: "帖子"),
  "POST": (ko: "게시하기", ja: "投稿", zh: "发布"),
  "POST TO": (ko: "게시할 곳", ja: "投稿先", zh: "发布到"),
  "COMMENTS": (ko: "댓글", ja: "コメント", zh: "评论"),
  "BETS": (ko: "베팅", ja: "予想", zh: "竞猜"),
  "Bets": (ko: "베팅", ja: "予想", zh: "竞猜"),
  "BET": (ko: "베팅", ja: "予想", zh: "竞猜"),
  "BETTING": (ko: "베팅", ja: "予想", zh: "竞猜"),
  "POINTS": (ko: "승점", ja: "ポイント", zh: "积分"),
  "SETTINGS": (ko: "설정", ja: "設定", zh: "设置"),
  "About": (ko: "앱 정보", ja: "アプリについて", zh: "关于"),
  "Contact": (ko: "문의", ja: "お問い合わせ", zh: "联系我们"),
  "Contact Us": (ko: "문의하기", ja: "お問い合わせ", zh: "联系我们"),
  "General": (ko: "자유", ja: "一般", zh: "通用"),
  "Legal": (ko: "법적 고지", ja: "法的情報", zh: "法律信息"),
  "Preferences": (ko: "환경 설정", ja: "環境設定", zh: "偏好设置"),
  "Account": (ko: "개인 정보", ja: "個人情報", zh: "个人信息"),
  "Notification": (ko: "알림", ja: "通知", zh: "通知"),
  "Notifications": (ko: "알림", ja: "通知", zh: "通知"),
  "All Notifications": (ko: "모든 알림", ja: "すべての通知", zh: "所有通知"),
  "Language": (ko: "언어", ja: "言語", zh: "语言"),
  "LANGUAGE": (ko: "언어", ja: "言語", zh: "语言"),
  "Device language": (ko: "기기 언어", ja: "端末の言語", zh: "设备语言"),
  "Follows your device language": (
    ko: "기기의 언어 설정을 따라요",
    ja: "端末の言語設定に従います",
    zh: "跟随设备语言设置"
  ),
  "Unit": (ko: "단위", ja: "単位", zh: "单位"),
  "UNIT": (ko: "단위", ja: "単位", zh: "单位"),
  "Currency": (ko: "통화", ja: "通貨", zh: "货币"),
  "CURRENCY": (ko: "통화", ja: "通貨", zh: "货币"),
  "English": (ko: "영어", ja: "英語", zh: "英语"),
  "Korean": (ko: "한국어", ja: "韓国語", zh: "韩语"),
  "Japanese": (ko: "일본어", ja: "日本語", zh: "日语"),
  "Chinese": (ko: "중국어", ja: "中国語", zh: "中文"),
  "Metric (cm)": (ko: "미터법(cm)", ja: "メートル法(cm)", zh: "公制(cm)"),
  "Imperial (ft/in)": (
    ko: "야드파운드법(ft/in)",
    ja: "ヤード・ポンド法(ft/in)",
    zh: "英制(ft/in)"
  ),
  "UPDATE PREFERENCES": (ko: "저장하기", ja: "設定を保存", zh: "保存设置"),
  "UPDATE NOTIFICATIONS": (ko: "알림 설정 저장하기", ja: "通知設定を保存", zh: "保存通知设置"),
  "UPDATE INFO": (ko: "저장하기", ja: "UPDATE INFO", zh: "UPDATE INFO"),
  "Dark Theme": (ko: "다크 모드", ja: "ダークモード", zh: "深色模式"),
  "Use dark theme": (ko: "다크 모드 사용", ja: "ダークモードにする", zh: "使用深色模式"),
  "Use light theme": (ko: "라이트 모드 사용", ja: "ライトモードにする", zh: "使用浅色模式"),
  "SOCIAL ACCOUNTS": (ko: "소셜 계정", ja: "ソーシャルアカウント", zh: "社交账号"),
  "Connected": (ko: "연결됨", ja: "連携済み", zh: "已关联"),
  "Not Connected": (ko: "연결 안 됨", ja: "未連携", zh: "未关联"),
  "Unable to connect {provider}. It may already be linked to another account.":
      (
    ko: "{provider} 계정을 연결할 수 없어요. 다른 계정에 이미 연결됐을 수 있어요.",
    ja: "{provider}を連携できません。別のアカウントに連携済みの可能性があります。",
    zh: "无法关联{provider}，该账号可能已关联其他账户。",
  ),
  "DELETE ACCOUNT": (ko: "계정 삭제하기", ja: "アカウントを削除", zh: "删除账号"),
  "Privacy Policy": (ko: "개인정보 처리방침", ja: "プライバシーポリシー", zh: "隐私政策"),
  "Terms of Service": (ko: "이용약관", ja: "利用規約", zh: "服务条款"),
  "Name": (ko: "이름", ja: "名前", zh: "姓名"),
  "Choose from Photos": (ko: "사진에서 선택", ja: "写真から選択", zh: "从照片中选择"),
  "Choose from Gallery": (ko: "갤러리에서 선택", ja: "ギャラリーから選択", zh: "从相册中选择"),
  "Remove Photo": (ko: "사진 삭제", ja: "写真を削除", zh: "删除照片"),
  "Unable to remove profile photo. Please try again.": (
    ko: "프로필 사진을 삭제하지 못했어요. 다시 시도해 주세요.",
    ja: "プロフィール写真を削除できませんでした。もう一度お試しください。",
    zh: "无法删除头像，请重试。"
  ),
  "Unable to update profile photo. Please try again.": (
    ko: "프로필 사진을 변경하지 못했어요. 다시 시도해 주세요.",
    ja: "プロフィール写真を変更できませんでした。もう一度お試しください。",
    zh: "无法更新头像，请重试。"
  ),
  "Unable to load Profile.": (
    ko: "프로필을 불러오지 못했어요.",
    ja: "プロフィールを読み込めませんでした。",
    zh: "无法加载个人资料。"
  ),
  "Unable to load activity counts.": (
    ko: "게시글·댓글 수를 불러오지 못했어요.",
    ja: "投稿・コメント数を読み込めませんでした。",
    zh: "无法加载帖子和评论数量。"
  ),
  "Retry": (ko: "다시 시도", ja: "再試行", zh: "重试"),
  "RETRY": (ko: "다시 시도", ja: "再試行", zh: "重试"),
  "Cancel": (ko: "취소", ja: "キャンセル", zh: "取消"),
  "Log out?": (ko: "로그아웃할까요?", ja: "ログアウトしますか？", zh: "要退出登录吗？"),
  "You will need to sign in again to use 1touch.": (
    ko: "1touch를 사용하려면 다시 로그인해야 해요.",
    ja: "1touchを利用するには、もう一度ログインする必要があります。",
    zh: "要继续使用 1touch，您需要重新登录。"
  ),
  "Log out": (ko: "로그아웃", ja: "ログアウト", zh: "退出登录"),
  "Logging out...": (ko: "로그아웃 중...", ja: "ログアウト中...", zh: "正在退出..."),
  "CANCEL": (ko: "취소", ja: "キャンセル", zh: "取消"),
  "Back": (ko: "뒤로", ja: "戻る", zh: "返回"),
  "DONE": (ko: "완료", ja: "完了", zh: "完成"),
  "UPDATE": (ko: "저장하기", ja: "保存", zh: "保存"),
  "Accept": (ko: "동의", ja: "同意する", zh: "同意"),
  "See all": (ko: "모두 보기", ja: "すべて見る", zh: "查看全部"),
  "See All": (ko: "모두 보기", ja: "すべて見る", zh: "查看全部"),
  "Loading": (ko: "불러오는 중", ja: "読み込み中", zh: "加载中"),
  "Loading…": (ko: "불러오는 중…", ja: "読み込み中…", zh: "加载中…"),
  "Unavailable": (ko: "정보 없음", ja: "データなし", zh: "暂无数据"),
  "Unknown": (ko: "알 수 없음", ja: "不明", zh: "未知"),
  "Unknown user": (ko: "알 수 없는 사용자", ja: "不明なユーザー", zh: "未知用户"),
  "Unknown Team": (ko: "알 수 없는 팀", ja: "不明なチーム", zh: "未知球队"),
  "Unknown Player": (ko: "알 수 없는 선수", ja: "不明な選手", zh: "未知球员"),
  "Unknown League": (ko: "알 수 없는 리그", ja: "不明なリーグ", zh: "未知联赛"),
  "Unknown Match": (ko: "알 수 없는 경기", ja: "不明な試合", zh: "未知比赛"),
  "Please check your connection and try again.": (
    ko: "연결 상태를 확인하고 다시 시도해 주세요.",
    ja: "接続を確認して再度お試しください。",
    zh: "请检查网络连接后重试。"
  ),
  "Your session expired. Please sign in again.": (
    ko: "로그인 세션이 만료됐어요.",
    ja: "セッションの有効期限が切れました。再度ログインしてください。",
    zh: "登录已过期，请重新登录。"
  ),
  "SEARCH UNAVAILABLE": (ko: "검색할 수 없어요", ja: "検索できません", zh: "无法搜索"),
  "NO RESULTS": (ko: "검색 결과가 없어요", ja: "検索結果がありません", zh: "没有搜索结果"),
  "Clear search": (ko: "검색어 지우기", ja: "検索をクリア", zh: "清空搜索"),
  "Search players, teams and matches": (
    ko: "선수, 팀, 경기 검색",
    ja: "選手・チーム・試合を検索",
    zh: "搜索球员、球队和比赛"
  ),
  "Search...": (ko: "검색…", ja: "検索…", zh: "搜索…"),
  "Search players": (ko: "선수 검색", ja: "選手を検索", zh: "搜索球员"),
  "Search players...": (ko: "선수 검색…", ja: "選手を検索…", zh: "搜索球员…"),
  "Look for players": (ko: "선수를 찾아보세요", ja: "選手を探す", zh: "查找球员"),
  "Search a team!": (ko: "팀 검색", ja: "チームを検索", zh: "搜索球队"),
  "Filter": (ko: "필터", ja: "フィルター", zh: "筛选"),
  "FILTER": (ko: "필터", ja: "フィルター", zh: "筛选"),
  "Ranking filters": (ko: "순위 필터", ja: "ランキングの絞り込み", zh: "排名筛选"),
  "UPDATE FILTER": (ko: "필터 적용", ja: "絞り込みを適用", zh: "应用筛选"),
  "ALL": (ko: "전체", ja: "すべて", zh: "全部"),
  "All": (ko: "전체", ja: "すべて", zh: "全部"),
  "ALL LEAGUES": (ko: "모든 리그", ja: "すべてのリーグ", zh: "所有联赛"),
  "All leagues": (ko: "모든 리그", ja: "すべてのリーグ", zh: "所有联赛"),
  "All matches": (ko: "모든 경기", ja: "すべての試合", zh: "所有比赛"),
  "All positions": (ko: "모든 포지션", ja: "すべてのポジション", zh: "所有位置"),
  "EVENTS": (ko: "경기", ja: "試合", zh: "比赛"),
  "FOLLOWING TEAMS": (ko: "팔로우한 팀", ja: "フォロー中のチーム", zh: "关注的球队"),
  "FOLLOWING PLAYERS": (ko: "팔로우한 선수", ja: "フォロー中の選手", zh: "关注的球员"),
  "Following Teams": (ko: "팔로우한 팀", ja: "フォロー中のチーム", zh: "关注的球队"),
  "Following Players": (ko: "팔로우한 선수", ja: "フォロー中の選手", zh: "关注的球员"),
  "FAVORITE TEAM": (ko: "좋아하는 팀", ja: "お気に入りのチーム", zh: "最喜欢的球队"),
  "FAVORITE PLAYERS": (ko: "좋아하는 선수", ja: "お気に入りの選手", zh: "喜欢的球员"),
  "Following": (ko: "팔로잉", ja: "フォロー中", zh: "已关注"),
  "Followers": (ko: "팔로워", ja: "フォロワー", zh: "粉丝"),
  "Follow player": (ko: "선수 팔로우", ja: "選手をフォロー", zh: "关注球员"),
  "Unfollow player": (ko: "선수 팔로우 취소", ja: "選手のフォローを解除", zh: "取消关注球员"),
  "Follow team": (ko: "팀 팔로우", ja: "チームをフォロー", zh: "关注球队"),
  "Unfollow team": (ko: "팀 팔로우 취소", ja: "チームのフォローを解除", zh: "取消关注球队"),
  "Edit favorites": (ko: "즐겨찾기 수정", ja: "お気に入りを編集", zh: "编辑收藏"),
  "Add favorite players": (ko: "좋아하는 선수 추가", ja: "お気に入りの選手を追加", zh: "添加喜欢的球员"),
  "You aren't following any players yet.\nAdd some now.": (
    ko: "팔로우 하는 선수가 아직 없어요.\n지금 추가해보세요.",
    ja: "フォローしている選手はまだいません。\n今すぐ追加しましょう。",
    zh: "还没有关注的球员。\n现在添加吧。"
  ),
  "Remove player": (ko: "선수 삭제", ja: "選手を削除", zh: "移除球员"),
  "Search players to add!": (
    ko: "선수 이름을 검색해 주세요",
    ja: "追加する選手を検索しましょう！",
    zh: "搜索要添加的球员！"
  ),
  "Search teams to add!": (
    ko: "팀 이름을 검색해 주세요",
    ja: "追加するチームを検索しましょう！",
    zh: "搜索要添加的球队！"
  ),
  "At least one team must stay followed.": (
    ko: "최소 한 팀은 팔로우해야 해요.",
    ja: "最低1チームはフォローしてください。",
    zh: "请至少保留一支关注的球队。"
  ),
  "Unable to save teams. Please try again.": (
    ko: "팀을 저장하지 못했어요. 다시 시도해 주세요.",
    ja: "チームを保存できませんでした。もう一度お試しください。",
    zh: "无法保存球队，请重试。"
  ),
  "Unable to update followed teams. Please try again.": (
    ko: "팔로우한 팀을 변경하지 못했어요. 다시 시도해 주세요.",
    ja: "フォロー中のチームを変更できませんでした。もう一度お試しください。",
    zh: "无法更新关注的球队，请重试。"
  ),
  "You can post, comment and like only in your favorite team community.": (
    ko: "최애팀 커뮤니티에서만 글·댓글·좋아요를 남길 수 있어요.",
    ja: "投稿・コメント・いいねは、最も好きなチームのコミュニティでのみ利用できます。",
    zh: "仅可在最喜欢的球队社区发帖、评论和点赞。"
  ),
  "Unable to change favorite team. Please try again.": (
    ko: "가장 좋아하는 팀을 변경하지 못했어요. 다시 시도해 주세요.",
    ja: "お気に入りのチームを変更できませんでした。もう一度お試しください。",
    zh: "无法更改最喜欢的球队，请重试。"
  ),
  "Could not load favorites": (
    ko: "즐겨찾기를 불러오지 못했어요",
    ja: "お気に入りを読み込めませんでした",
    zh: "无法加载收藏"
  ),
  "Could not load favorites · Retry": (
    ko: "즐겨찾기를 불러오지 못했어요 · 다시 시도",
    ja: "お気に入りを読み込めませんでした · 再試行",
    zh: "无法加载收藏 · 重试"
  ),
  "Could not save favorites": (
    ko: "즐겨찾기를 저장하지 못했어요",
    ja: "お気に入りを保存できませんでした",
    zh: "无法保存收藏"
  ),
  "Could not load players · Retry": (
    ko: "선수를 불러오지 못했어요 · 다시 시도",
    ja: "選手を読み込めませんでした · 再試行",
    zh: "无法加载球员 · 重试"
  ),
  "Could not load ranking · Retry": (
    ko: "순위를 불러오지 못했어요 · 다시 시도",
    ja: "ランキングを読み込めませんでした · 再試行",
    zh: "无法加载排名 · 重试"
  ),
  "Could not load player data": (
    ko: "선수 정보를 불러오지 못했어요",
    ja: "選手情報を読み込めませんでした",
    zh: "无法加载球员信息"
  ),
  "Could not load player data. Please select the player again.": (
    ko: "선수 정보를 불러오지 못했어요. 선수를 다시 선택해 주세요.",
    ja: "選手情報を読み込めませんでした。選手を選び直してください。",
    zh: "无法加载球员信息，请重新选择球员。"
  ),
  "No players found": (ko: "선수를 찾지 못했어요", ja: "選手が見つかりません", zh: "未找到球员"),
  "No teams found": (ko: "팀을 찾지 못했어요", ja: "チームが見つかりません", zh: "未找到球队"),
  "Overview": (ko: "개요", ja: "概要", zh: "概览"),
  "Matches": (ko: "경기", ja: "試合", zh: "比赛"),
  "MATCHES": (ko: "경기", ja: "試合", zh: "比赛"),
  "Squad": (ko: "스쿼드", ja: "選手一覧", zh: "阵容"),
  "Standing": (ko: "순위", ja: "順位表", zh: "积分榜"),
  "STANDING": (ko: "순위표", ja: "順位表", zh: "积分榜"),
  "Analysis": (ko: "분석", ja: "分析", zh: "分析"),
  "ANALYSIS": (ko: "분석", ja: "分析", zh: "分析"),
  "News": (ko: "뉴스", ja: "ニュース", zh: "新闻"),
  "NEWS": (ko: "뉴스", ja: "ニュース", zh: "新闻"),
  "News & Insights": (ko: "뉴스·정보", ja: "ニュースとインサイト", zh: "新闻与洞察"),
  "Fan Art": (ko: "팬아트", ja: "ファンアート", zh: "同人创作"),
  "HIGHLIGHTS": (ko: "하이라이트", ja: "ハイライト", zh: "集锦"),
  "HIGHLIGHTS UNAVAILABLE": (
    ko: "하이라이트를 볼 수 없어요",
    ja: "ハイライトを再生できません",
    zh: "无法播放集锦"
  ),
  "No highlights available yet.": (
    ko: "아직 하이라이트가 없어요.",
    ja: "ハイライトはまだありません。",
    zh: "暂无集锦。"
  ),
  "No team news yet.": (
    ko: "아직 팀 뉴스가 없어요.",
    ja: "チームのニュースはまだありません。",
    zh: "暂无球队新闻。"
  ),
  "Unable to load news.": (
    ko: "뉴스를 불러오지 못했어요.",
    ja: "ニュースを読み込めませんでした。",
    zh: "无法加载新闻。"
  ),
  "Unable to load Home.": (
    ko: "홈을 불러오지 못했어요.",
    ja: "ホームを読み込めませんでした。",
    zh: "无法加载首页。"
  ),
  "No matches available": (ko: "경기가 없어요", ja: "試合がありません", zh: "暂无比赛"),
  "Unable to load matches": (
    ko: "경기를 불러오지 못했어요",
    ja: "試合を読み込めませんでした",
    zh: "无法加载比赛"
  ),
  "Unable to load match.": (
    ko: "경기를 불러오지 못했어요.",
    ja: "試合を読み込めませんでした。",
    zh: "无法加载比赛。"
  ),
  "Match not found": (ko: "경기를 찾을 수 없어요", ja: "試合が見つかりません", zh: "未找到比赛"),
  "Competition unavailable": (ko: "대회 정보가 없어요", ja: "大会情報がありません", zh: "暂无赛事信息"),
  "Team unavailable": (ko: "팀 정보가 없어요", ja: "チーム情報がありません", zh: "暂无球队信息"),
  "Unable to load team": (
    ko: "팀을 불러오지 못했어요",
    ja: "チームを読み込めませんでした",
    zh: "无法加载球队"
  ),
  "NEXT MATCH": (ko: "다음 경기", ja: "次の試合", zh: "下一场比赛"),
  "LAST MATCH": (ko: "지난 경기", ja: "前の試合", zh: "上一场比赛"),
  "LIVE MATCH": (ko: "진행 중인 경기", ja: "ライブ中の試合", zh: "进行中的比赛"),
  "LIVE": (ko: "라이브", ja: "ライブ", zh: "直播"),
  "Live": (ko: "라이브", ja: "ライブ", zh: "直播"),
  "• LIVE": (ko: "● 진행 중인 경기", ja: "• ライブ", zh: "• 直播"),
  "FIXTURE": (ko: "경기 일정", ja: "試合日程", zh: "赛程"),
  "CALENDAR": (ko: "캘린더", ja: "カレンダー", zh: "日历"),
  "RECENT MATCHES": (ko: "최근 경기", ja: "最近の試合", zh: "近期比赛"),
  "PAST MATCHES": (ko: "지난 경기", ja: "過去の試合", zh: "过往比赛"),
  "PAST": (ko: "지난 경기", ja: "過去の試合", zh: "已结束"),
  "UPCOMING": (ko: "다가오는 경기", ja: "今後の試合", zh: "即将开始"),
  "Date TBD": (ko: "날짜 미정", ja: "日程未定", zh: "日期待定"),
  "DATE TBD": (ko: "날짜 미정", ja: "日程未定", zh: "日期待定"),
  "Time TBD": (ko: "시간 미정", ja: "時間未定", zh: "时间待定"),
  "Round TBD": (ko: "라운드 미정", ja: "ラウンド未定", zh: "轮次待定"),
  "TBD": (ko: "미정", ja: "未定", zh: "待定"),
  "ROUND": (ko: "라운드", ja: "ラウンド", zh: "轮次"),
  "SEASON": (ko: "시즌", ja: "シーズン", zh: "赛季"),
  "Season": (ko: "시즌", ja: "シーズン", zh: "赛季"),
  "Current season": (ko: "현재 시즌", ja: "今シーズン", zh: "当前赛季"),
  "Current season only.": (
    ko: "현재 시즌만 제공해요.",
    ja: "今シーズンのみです。",
    zh: "仅提供当前赛季。"
  ),
  "SELECT A SEASON": (ko: "시즌 선택", ja: "シーズンを選択", zh: "选择赛季"),
  "Select a season with league appearances": (
    ko: "리그 출전 기록이 있는 시즌을 선택해 주세요",
    ja: "リーグ出場記録のあるシーズンを選択してください",
    zh: "请选择有联赛出场记录的赛季"
  ),
  "LEAGUE": (ko: "리그", ja: "リーグ", zh: "联赛"),
  "League": (ko: "리그", ja: "リーグ", zh: "联赛"),
  "Cup": (ko: "컵 대회", ja: "カップ戦", zh: "杯赛"),
  "COMPETITION": (ko: "대회", ja: "大会", zh: "赛事"),
  "BRACKET": (ko: "대진표", ja: "トーナメント表", zh: "对阵图"),
  "XG TABLE": (ko: "xG 순위표", ja: "xG順位表", zh: "xG积分榜"),
  "No standings available": (ko: "순위표가 없어요", ja: "順位表がありません", zh: "暂无积分榜"),
  "No xG standings available": (
    ko: "xG 순위표가 없어요",
    ja: "xG順位表がありません",
    zh: "暂无xG积分榜"
  ),
  "Unable to load standings": (
    ko: "순위표를 불러오지 못했어요",
    ja: "順位表を読み込めませんでした",
    zh: "无法加载积分榜"
  ),
  "Unable to load xG standings": (
    ko: "xG 순위표를 불러오지 못했어요",
    ja: "xG順位表を読み込めませんでした",
    zh: "无法加载xG积分榜"
  ),
  "Retry standings": (ko: "순위표 다시 불러오기", ja: "順位表を再読み込み", zh: "重新加载积分榜"),
  "Unable to load bracket.": (
    ko: "대진표를 불러오지 못했어요.",
    ja: "トーナメント表を読み込めませんでした。",
    zh: "无法加载对阵图。"
  ),
  "Bracket has not been published yet.": (
    ko: "아직 대진표가 발표되지 않았어요.",
    ja: "トーナメント表はまだ公開されていません。",
    zh: "对阵图尚未公布。"
  ),
  "FINAL": (ko: "결승", ja: "決勝", zh: "决赛"),
  "Final": (ko: "결승", ja: "決勝", zh: "决赛"),
  "SEMIFINAL": (ko: "준결승", ja: "準決勝", zh: "半决赛"),
  "SEMIFINALS": (ko: "준결승", ja: "準決勝", zh: "半决赛"),
  "QUARTERFINAL": (ko: "8강", ja: "準々決勝", zh: "四分之一决赛"),
  "QUARTERFINALS": (ko: "8강", ja: "準々決勝", zh: "四分之一决赛"),
  "R16": (ko: "16강", ja: "ベスト16", zh: "十六强"),
  "QF": (ko: "8강", ja: "準々決勝", zh: "八强"),
  "SF": (ko: "4강", ja: "準決勝", zh: "四强"),
  "Club": (ko: "팀", ja: "クラブ", zh: "俱乐部"),
  "MP": (ko: "경기", ja: "試合", zh: "场次"),
  "W": (ko: "승", ja: "勝", zh: "胜"),
  "D": (ko: "무", ja: "分", zh: "平"),
  "L": (ko: "패", ja: "敗", zh: "负"),
  "GF": (ko: "득점", ja: "得点", zh: "进球"),
  "GA": (ko: "실점", ja: "失点", zh: "失球"),
  "GD": (ko: "득실", ja: "得失点差", zh: "净胜球"),
  "PTS": (ko: "승점", ja: "勝点", zh: "积分"),
  "Pts": (ko: "승점", ja: "勝点", zh: "积分"),
  "Collapse club names to short codes": (
    ko: "팀 이름을 약칭으로 표시",
    ja: "クラブ名を略称で表示",
    zh: "显示球队简称"
  ),
  "Expand all club short codes to full names": (
    ko: "팀 이름을 전체 이름으로 표시",
    ja: "クラブ名を正式名称で表示",
    zh: "显示球队全称"
  ),
  "POSITION": (ko: "포지션", ja: "ポジション", zh: "位置"),
  "Position": (ko: "포지션", ja: "ポジション", zh: "位置"),
  "POSITION UNAVAILABLE": (ko: "포지션 정보 없음", ja: "ポジション情報なし", zh: "暂无位置信息"),
  "GOALKEEPER": (ko: "골키퍼", ja: "ゴールキーパー", zh: "守门员"),
  "DEFENDER": (ko: "수비수", ja: "ディフェンダー", zh: "后卫"),
  "DEFENDERS": (ko: "수비수", ja: "ディフェンダー", zh: "后卫"),
  "MIDFIELDER": (ko: "미드필더", ja: "ミッドフィルダー", zh: "中场"),
  "MIDFIELDERS": (ko: "미드필더", ja: "ミッドフィルダー", zh: "中场"),
  "FORWARD": (ko: "공격수", ja: "フォワード", zh: "前锋"),
  "ATTACKERS": (ko: "공격수", ja: "フォワード", zh: "前锋"),
  "Goalkeeper": (ko: "골키퍼", ja: "ゴールキーパー", zh: "守门员"),
  "Defender": (ko: "수비수", ja: "ディフェンダー", zh: "后卫"),
  "Midfielder": (ko: "미드필더", ja: "ミッドフィルダー", zh: "中场"),
  "Forward": (ko: "공격수", ja: "フォワード", zh: "前锋"),
  "Age": (ko: "나이", ja: "年齢", zh: "年龄"),
  "Height": (ko: "키", ja: "身長", zh: "身高"),
  "Weight": (ko: "몸무게", ja: "体重", zh: "体重"),
  "Jersey Number": (ko: "등번호", ja: "背番号", zh: "球衣号码"),
  "Wage": (ko: "급여", ja: "給与", zh: "薪资"),
  "Contract Length": (ko: "계약 기간", ja: "契約期間", zh: "合同期限"),
  "Squad Role": (ko: "팀 내 역할", ja: "チームでの役割", zh: "队内角色"),
  "Complete contract dates are currently unavailable.": (
    ko: "전체 계약 기간 정보가 없어요.",
    ja: "契約期間の詳細情報はありません。",
    zh: "暂无完整的合同期限信息。"
  ),
  "Wage data is unavailable.": (
    ko: "급여 정보가 없어요.",
    ja: "給与情報がありません。",
    zh: "暂无薪资信息。"
  ),
  "Unable to load squad": (
    ko: "선수단을 불러오지 못했어요",
    ja: "選手一覧を読み込めませんでした",
    zh: "无法加载阵容"
  ),
  "ASCENDING": (ko: "오름차순", ja: "昇順", zh: "升序"),
  "DESCENDING": (ko: "내림차순", ja: "降順", zh: "降序"),
  "BEST ELEVEN": (ko: "베스트 11", ja: "ベストイレブン", zh: "最佳十一人"),
  "BEST XI": (ko: "베스트 11", ja: "ベストイレブン", zh: "最佳十一人"),
  "No best eleven available": (
    ko: "베스트 일레븐 정보가 없어요",
    ja: "ベストイレブンの情報がありません",
    zh: "暂无最佳阵容"
  ),
  "Unable to load best eleven": (
    ko: "베스트 일레븐을 불러오지 못했어요",
    ja: "ベストイレブンを読み込めませんでした",
    zh: "无法加载最佳阵容"
  ),
  "ATTRIBUTES": (ko: "능력치", ja: "能力", zh: "能力值"),
  "ATTACK": (ko: "공격", ja: "攻撃", zh: "进攻"),
  "Attack": (ko: "공격", ja: "攻撃", zh: "进攻"),
  "DEFENSE": (ko: "수비", ja: "守備", zh: "防守"),
  "Defending": (ko: "수비력", ja: "守備力", zh: "防守"),
  "Possession & Build-Up": (ko: "점유·빌드업", ja: "ポゼッション・ビルドアップ", zh: "控球与推进"),
  "Attacking Threat": (ko: "공격 위협", ja: "攻撃の脅威", zh: "进攻威胁"),
  "Chance Creation": (ko: "기회 창출", ja: "チャンス創出", zh: "机会创造"),
  "Shooting & Finishing": (ko: "슈팅·마무리", ja: "シュート・フィニッシュ", zh: "射门与终结"),
  "POSSESSION": (ko: "점유", ja: "ポゼッション", zh: "控球"),
  "Possession": (ko: "점유", ja: "ポゼッション", zh: "控球"),
  "PROGRESSION": (ko: "전진", ja: "前進", zh: "推进"),
  "LINK-UP": (ko: "연계", ja: "連携", zh: "串联"),
  "DRIBBLE": (ko: "드리블", ja: "ドリブル", zh: "盘带"),
  "PLAY-MAKING": (ko: "플레이메이킹", ja: "チャンスメイク", zh: "组织进攻"),
  "No attribute data available": (
    ko: "능력치 정보가 없어요",
    ja: "能力データがありません",
    zh: "暂无能力数据"
  ),
  "CURRENT FORM": (ko: "최근 경기력", ja: "直近の調子", zh: "近期状态"),
  "Current form data is not available yet": (
    ko: "아직 최근 경기력 정보가 없어요",
    ja: "直近の調子のデータはまだありません",
    zh: "暂无近期状态数据"
  ),
  "Unable to load current form": (
    ko: "최근 경기력을 불러오지 못했어요",
    ja: "直近の調子を読み込めませんでした",
    zh: "无法加载近期状态"
  ),
  "PROBABILITY": (ko: "예상 확률", ja: "予測確率", zh: "预测概率"),
  "Probability": (ko: "예상 확률", ja: "予測確率", zh: "预测概率"),
  "PROBABILITY HISTORY": (ko: "예상 확률 변화", ja: "予測確率の推移", zh: "预测概率走势"),
  "PROJECTED FINAL POSITION": (ko: "예상 최종 순위", ja: "予想最終順位", zh: "预计最终排名"),
  "PROJECTED POINTS": (ko: "예상 승점", ja: "予想勝点", zh: "预计积分"),
  "Likely range of": (ko: "예상 범위", ja: "予想範囲", zh: "预计范围"),
  "WHAT IF?": (ko: "만약에?", ja: "もしも？", zh: "如果？"),
  "What if?": (ko: "만약에?", ja: "もしも？", zh: "如果？"),
  "IF {team}'S NEXT MATCH ENDS WITH": (
    ko: "{team}의 다음 경기 결과가",
    ja: "{team}の次の試合結果が",
    zh: "如果{team}下一场比赛结果是"
  ),
  "Team": (ko: "팀", ja: "チーム", zh: "球队"),
  "Round": (ko: "라운드", ja: "ラウンド", zh: "轮次"),
  "Next match": (ko: "다음 경기", ja: "次の試合", zh: "下一场比赛"),
  "LEAGUE WINNER PROBABILITY": (ko: "리그 우승 확률", ja: "リーグ優勝確率", zh: "联赛夺冠概率"),
  "TOP 4 PROBABILITY": (ko: "TOP 4 확률", ja: "トップ4確率", zh: "前四概率"),
  "RELEGATION PROBABILITY": (ko: "강등 확률", ja: "降格確率", zh: "降级概率"),
  "If win": (ko: "승리 시", ja: "勝利時", zh: "获胜时"),
  "If draw": (ko: "무승부 시", ja: "引き分け時", zh: "平局时"),
  "If loss": (ko: "패배 시", ja: "敗戦時", zh: "失利时"),
  "What-if data is unavailable.": (
    ko: "What if 데이터를 이용할 수 없어요.",
    ja: "What ifデータを利用できません。",
    zh: "What if 数据不可用。"
  ),
  "What-if data is unavailable for this outcome.": (
    ko: "이 결과의 What if 데이터를 이용할 수 없어요.",
    ja: "この結果のWhat ifデータを利用できません。",
    zh: "此结果的 What if 数据不可用。"
  ),
  "A win could change {team}'s probability by {win} percentage points, while a loss could change it by {loss} points.":
      (
    ko: "승리하면 {team}의 확률이 {win}%p, 패배하면 {loss}%p 변할 수 있어요.",
    ja: "勝利すると{team}の確率が{win}ポイント、敗戦すると{loss}ポイント変化する可能性があります。",
    zh: "获胜可能使{team}的概率变化{win}个百分点，失利则可能变化{loss}个百分点。"
  ),
  "Chances to Win\nLeague Trophy": (
    ko: "리그 우승 확률",
    ja: "リーグ\n優勝確率",
    zh: "联赛\n夺冠概率"
  ),
  "Chances to Win\nUCL Trophy": (
    ko: "UCL 우승 확률",
    ja: "UCL\n優勝確率",
    zh: "UCL\n夺冠概率"
  ),
  "Chances to Win\nUEL Trophy": (
    ko: "UEL 우승 확률",
    ja: "UEL\n優勝確率",
    zh: "UEL\n夺冠概率"
  ),
  "Chances to Win\nUECL Trophy": (
    ko: "UECL 우승 확률",
    ja: "UECL\n優勝確率",
    zh: "UECL\n夺冠概率"
  ),
  "Chances to Finish\nTop 4": (
    ko: "4위 이내 진입 확률",
    ja: "4位以内の\n確率",
    zh: "进入前四的\n概率"
  ),
  "Chances to Finish\nTop 6": (
    ko: "6위 이내 진입 확률",
    ja: "6位以内の\n確率",
    zh: "进入前六的\n概率"
  ),
  "Chances of\nRelegation": (ko: "강등 확률", ja: "降格の\n確率", zh: "降级的\n概率"),
  "Chances of Relegation\nPlayoff": (
    ko: "강등 PO 확률",
    ja: "降格プレーオフの\n確率",
    zh: "参加保级附加赛的\n概率"
  ),
  "Prediction unavailable.": (
    ko: "예측 정보가 없어요.",
    ja: "予測データがありません。",
    zh: "暂无预测数据。"
  ),
  "Prediction unavailable for this match.": (
    ko: "이 경기의 예측 정보가 없어요.",
    ja: "この試合の予測データはありません。",
    zh: "暂无本场比赛的预测数据。"
  ),
  "Retry probability": (ko: "예상 확률 다시 불러오기", ja: "予測確率を再読み込み", zh: "重新加载预测概率"),
  "Chances to win\nLEAGUE Trophy": (
    ko: "리그 우승 확률",
    ja: "リーグ\n優勝確率",
    zh: "联赛\n夺冠概率"
  ),
  "Chances to win\nUCL Trophy": (
    ko: "UCL 우승 확률",
    ja: "UCL\n優勝確率",
    zh: "UCL\n夺冠概率"
  ),
  "Chances to win\nUEL Trophy": (
    ko: "UEL 우승 확률",
    ja: "UEL\n優勝確率",
    zh: "UEL\n夺冠概率"
  ),
  "Chances to win\nUECL Trophy": (
    ko: "UECL 우승 확률",
    ja: "UECL\n優勝確率",
    zh: "UECL\n夺冠概率"
  ),
  "Chances to finish\nTOP 4": (
    ko: "4위 이내 진입 확률",
    ja: "4位以内の\n確率",
    zh: "进入前四的\n概率"
  ),
  "Chances to finish\nTOP 6": (
    ko: "6위 이내 진입 확률",
    ja: "6位以内の\n確率",
    zh: "进入前六的\n概率"
  ),
  "Chances of\nRELEGATION": (ko: "강등 확률", ja: "降格の\n確率", zh: "降级的\n概率"),
  "Chances of\nRELEGATION PLAYOFF": (
    ko: "강등 PO 확률",
    ja: "降格プレーオフの\n確率",
    zh: "参加保级附加赛的\n概率"
  ),
  "INJURY STATUS": (ko: "다친 선수", ja: "負傷状況", zh: "伤病情况"),
  "No current injuries": (ko: "현재 부상 선수가 없어요", ja: "現在、負傷者はいません", zh: "目前没有伤员"),
  "Unable to load injuries": (
    ko: "부상 정보를 불러오지 못했어요",
    ja: "負傷情報を読み込めませんでした",
    zh: "无法加载伤病信息"
  ),
  "Injury": (ko: "부상", ja: "負傷", zh: "伤病"),
  "TRANSFERS": (ko: "이적", ja: "移籍", zh: "转会"),
  "No transfers": (ko: "이적 내역이 없어요", ja: "移籍情報がありません", zh: "暂无转会记录"),
  "Unable to load transfers": (
    ko: "이적 정보를 불러오지 못했어요",
    ja: "移籍情報を読み込めませんでした",
    zh: "无法加载转会信息"
  ),
  "IN": (ko: "영입", ja: "加入", zh: "转入"),
  "OUT": (ko: "방출", ja: "退団", zh: "转出"),
  "FROM": (ko: "이전 팀", ja: "移籍元", zh: "来自"),
  "TO": (ko: "새 팀", ja: "移籍先", zh: "去向"),
  "Free Transfer": (ko: "자유 계약", ja: "フリー移籍", zh: "自由转会"),
  "Contract expired": (ko: "계약 만료", ja: "契約満了", zh: "合同到期"),
  "Return from loan": (ko: "임대 복귀", ja: "レンタル復帰", zh: "租借回归"),
  "Loan transfer": (ko: "임대", ja: "レンタル移籍", zh: "租借"),
  "No information": (ko: "정보 없음", ja: "情報なし", zh: "暂无信息"),
  "TROPHIES": (ko: "우승 기록", ja: "タイトル", zh: "荣誉"),
  "Team trophy records unavailable": (
    ko: "팀 우승 기록이 없어요",
    ja: "チームのタイトル記録がありません",
    zh: "暂无球队荣誉记录"
  ),
  "CLUB HISTORY": (ko: "클럽 경력", ja: "クラブ経歴", zh: "俱乐部生涯"),
  "Club history unavailable": (
    ko: "클럽 경력 정보가 없어요",
    ja: "クラブ経歴がありません",
    zh: "暂无俱乐部生涯信息"
  ),
  "No history available": (ko: "기록이 없어요", ja: "記録がありません", zh: "暂无记录"),
  "Career": (ko: "커리어", ja: "キャリア", zh: "职业生涯"),
  "COMPETITION STATS": (ko: "대회 기록", ja: "大会成績", zh: "赛事数据"),
  "Collected since 17/18 season": (
    ko: "17/18 시즌부터 집계",
    ja: "17/18シーズン以降の集計",
    zh: "自17/18赛季起统计"
  ),
  "A quick overview of the player's average performance in each competition. Data has been collected since the 2017/18 season.":
      (
    ko: "대회별 선수의 평균 경기력을 간단히 보여줘요. 데이터는 2017/18 시즌부터 집계했어요.",
    ja: "大会ごとの選手の平均的なパフォーマンスを簡単に示します。データは2017/18シーズンから集計しています。",
    zh: "简要展示球员在各项赛事中的平均表现。数据从2017/18赛季开始收集。"
  ),
  "No competitions this season": (
    ko: "이 시즌의 대회 기록이 없어요",
    ja: "このシーズンの大会記録はありません",
    zh: "本赛季暂无赛事记录"
  ),
  "No appearances this season": (
    ko: "이 시즌의 출전 기록이 없어요",
    ja: "このシーズンの出場記録はありません",
    zh: "本赛季暂无出场记录"
  ),
  "No rated appearances are available.": (
    ko: "평점이 있는 출전 기록이 없어요.",
    ja: "評価のある出場記録はありません。",
    zh: "暂无有评分的出场记录。"
  ),
  "No ratings available": (ko: "평점이 없어요", ja: "評価がありません", zh: "暂无评分"),
  "Rating": (ko: "평점", ja: "評価", zh: "评分"),
  "Form": (ko: "최근 경기력", ja: "調子", zh: "状态"),
  "PERFORMANCE": (ko: "경기력", ja: "パフォーマンス", zh: "表现"),
  "INFLUENCE": (ko: "영향력", ja: "影響力", zh: "影响力"),
  "Cost-Effectiveness": (ko: "급여 대비 효율", ja: "給与対効果", zh: "薪资性价比"),
  "An indicator is shown when enough data is available.": (
    ko: "데이터가 충분히 모이면 지표를 보여드려요.",
    ja: "十分なデータが集まると指標が表示されます。",
    zh: "数据充足时将显示指标。"
  ),
  "Could not load the indicators. Tap retry to try again.": (
    ko: "지표를 불러오지 못했어요. 다시 시도해 주세요.",
    ja: "指標を読み込めませんでした。再試行してください。",
    zh: "无法加载指标，请重试。"
  ),
  "Compared with all positions across the five leagues.": (
    ko: "5대 리그의 모든 포지션과 비교해요.",
    ja: "5大リーグの全ポジションと比較します。",
    zh: "与五大联赛所有位置的球员比较。"
  ),
  "Grades are based on prediction error, not equal-sized groups.": (
    ko: "등급은 같은 인원수로 나누지 않고 예측 오차를 기준으로 정해요.",
    ja: "等級は人数の均等割りではなく、予測誤差に基づきます。",
    zh: "等级根据预测误差划分，而非按人数等分。"
  ),
  "Player data unavailable": (ko: "선수 정보가 없어요", ja: "選手情報がありません", zh: "暂无球员信息"),
  "Player": (ko: "선수", ja: "選手", zh: "球员"),
  "1TOUCH RANKING": (ko: "1TOUCH 순위", ja: "1TOUCHランキング", zh: "1TOUCH排名"),
  "1touch Ranking": (ko: "1touch 순위", ja: "1touchランキング", zh: "1touch排名"),
  "No ranking data for these filters": (
    ko: "이 필터에 맞는 순위 정보가 없어요",
    ja: "この条件に合うランキングがありません",
    zh: "没有符合筛选条件的排名数据"
  ),
  "ONES TO WATCH": (ko: "주목할 선수", ja: "注目の選手", zh: "值得关注的球员"),
  "No players with 10 rated appearances and an improved average": (
    ko: "평점이 있는 10경기 출전과 평균 상승 조건을 충족한 선수가 없어요",
    ja: "評価付き10試合出場と平均上昇の条件を満たす選手はいません",
    zh: "没有满足10场评分出场且平均评分提升的球员"
  ),
  "MOST COMPARED": (ko: "많이 비교한 선수", ja: "よく比較される選手", zh: "热门对比球员"),
  "Comparison data unavailable": (
    ko: "비교 정보가 없어요",
    ja: "比較データがありません",
    zh: "暂无对比数据"
  ),
  "You can only pick players who play the same position.": (
    ko: "같은 포지션의 선수만 선택할 수 있어요.",
    ja: "同じポジションの選手のみ選択できます。",
    zh: "只能选择相同位置的球员。"
  ),
  "Goal": (ko: "골", ja: "ゴール", zh: "进球"),
  "Goals": (ko: "골", ja: "ゴール", zh: "进球"),
  "Assist": (ko: "도움", ja: "アシスト", zh: "助攻"),
  "Assists": (ko: "도움", ja: "アシスト", zh: "助攻"),
  "Shot": (ko: "슈팅", ja: "シュート", zh: "射门"),
  "Goal\nContributions": (ko: "공격\n포인트", ja: "ゴール\n関与", zh: "参与\n进球"),
  "Win Rate": (ko: "승률", ja: "勝率", zh: "胜率"),
  "Minutes Played\nPer Game": (
    ko: "경기당\n출전 시간",
    ja: "1試合あたりの\n出場時間",
    zh: "场均\n出场时间"
  ),
  "Starting Rate": (ko: "선발 비율", ja: "先発率", zh: "首发率"),
  "Starting / Substitute": (ko: "선발 / 교체", ja: "先発 / 途中出場", zh: "首发 / 替补"),
  "Pace": (ko: "속도", ja: "スピード", zh: "速度"),
  "Shooting": (ko: "슈팅", ja: "シュート", zh: "射门"),
  "Passing": (ko: "패스", ja: "パス", zh: "传球"),
  "Physical": (ko: "피지컬", ja: "フィジカル", zh: "身体"),
  "Reaction": (ko: "반응", ja: "反応", zh: "反应"),
  "MATCH INFO": (ko: "경기 정보", ja: "試合情報", zh: "比赛信息"),
  "MATCH PREVIEW": (ko: "경기 프리뷰", ja: "試合プレビュー", zh: "赛前分析"),
  "HEAD TO HEAD": (ko: "상대 전적", ja: "対戦成績", zh: "交锋记录"),
  "LATEST H2H": (ko: "최근 맞대결", ja: "直近の対戦", zh: "最近交锋"),
  "No previous meetings found.": (
    ko: "이전 맞대결이 없어요.",
    ja: "過去の対戦がありません。",
    zh: "没有历史交锋记录。"
  ),
  "Unable to load head-to-head matches.": (
    ko: "상대 전적을 불러오지 못했어요.",
    ja: "対戦成績を読み込めませんでした。",
    zh: "无法加载交锋记录。"
  ),
  "Unable to load the latest meeting.": (
    ko: "최근 맞대결을 불러오지 못했어요.",
    ja: "直近の対戦を読み込めませんでした。",
    zh: "无法加载最近交锋。"
  ),
  "Last 5": (ko: "최근 5경기", ja: "直近5試合", zh: "最近5场"),
  "Last {count}": (ko: "최근 {count}경기", ja: "直近{count}試合", zh: "最近{count}场"),
  "Win": (ko: "승", ja: "勝ち", zh: "胜"),
  "Draw": (ko: "무", ja: "引き分け", zh: "平"),
  "Lose": (ko: "패", ja: "負け", zh: "负"),
  "Home Win": (ko: "홈 승", ja: "ホーム勝利", zh: "主胜"),
  "Away Win": (ko: "원정 승", ja: "アウェイ勝利", zh: "客胜"),
  "AGAINST": (ko: "상대로", ja: "対戦相手", zh: "对手"),
  "LINEUP": (ko: "선발 명단", ja: "スターティングメンバー", zh: "首发阵容"),
  "COACH": (ko: "감독", ja: "監督", zh: "主教练"),
  "SUBSTITUTES": (ko: "교체 선수", ja: "控え選手", zh: "替补球员"),
  "PLAYER OF THE MATCH": (ko: "경기 최우수 선수", ja: "プレイヤー・オブ・ザ・マッチ", zh: "全场最佳球员"),
  "MOMENTUM": (ko: "경기 흐름", ja: "試合の流れ", zh: "比赛走势"),
  "TOP STATS": (ko: "주요 기록", ja: "主要スタッツ", zh: "关键数据"),
  "Ball Possession": (ko: "점유율", ja: "ボール支配率", zh: "控球率"),
  "Shots": (ko: "슈팅", ja: "シュート", zh: "射门"),
  "Shots on Target": (ko: "유효 슈팅", ja: "枠内シュート", zh: "射正"),
  "Completed Passes": (ko: "패스 성공", ja: "パス成功", zh: "成功传球"),
  "Pass Accuracy": (ko: "패스 성공률", ja: "パス成功率", zh: "传球成功率"),
  "Passes (Succ. / Attempts)": (
    ko: "패스 (성공 / 시도)",
    ja: "パス (成功 / 試行)",
    zh: "传球 (成功 / 尝试)"
  ),
  "Progressive Passes": (ko: "전진 패스", ja: "前進パス", zh: "推进传球"),
  "Passes into Final Third": (
    ko: "공격 지역 진입 패스",
    ja: "ファイナルサードへのパス",
    zh: "传入进攻三区"
  ),
  "Passes into Pen. Area": (ko: "페널티 지역 진입 패스", ja: "ペナルティエリアへのパス", zh: "传入禁区"),
  "Key Passes": (ko: "키 패스", ja: "キーパス", zh: "关键传球"),
  "Recoveries": (ko: "볼 회수", ja: "ボール回収", zh: "球权夺回"),
  "Tackles Won": (ko: "태클 성공", ja: "タックル成功", zh: "成功抢断"),
  "Duels Won": (ko: "경합 승리", ja: "デュエル勝利", zh: "对抗成功"),
  "Interceptions": (ko: "가로채기", ja: "インターセプト", zh: "拦截"),
  "Clearances": (ko: "걷어내기", ja: "クリア", zh: "解围"),
  "Blocks": (ko: "블록", ja: "ブロック", zh: "封堵"),
  "Saves": (ko: "선방", ja: "セーブ", zh: "扑救"),
  "Touches": (ko: "볼 터치", ja: "ボールタッチ", zh: "触球"),
  "Attempts": (ko: "시도", ja: "試行", zh: "尝试"),
  "Corners": (ko: "코너킥", ja: "コーナーキック", zh: "角球"),
  "Offsides": (ko: "오프사이드", ja: "オフサイド", zh: "越位"),
  "Fouls": (ko: "파울", ja: "ファウル", zh: "犯规"),
  "Yellow Cards": (ko: "경고", ja: "イエローカード", zh: "黄牌"),
  "Yellow Card": (ko: "경고", ja: "イエローカード", zh: "黄牌"),
  "Red Card": (ko: "퇴장", ja: "レッドカード", zh: "红牌"),
  "Substitution": (ko: "선수 교체", ja: "選手交代", zh: "换人"),
  "Distance Covered": (ko: "이동 거리", ja: "走行距離", zh: "跑动距离"),
  "Succ. Rate (Take-Ons)": (ko: "드리블 성공률", ja: "ドリブル成功率", zh: "过人成功率"),
  "success rate": (ko: "성공률", ja: "成功率", zh: "成功率"),
  "per 90": (ko: "90분당", ja: "90分あたり", zh: "每90分钟"),
  "Season total": (ko: "시즌 합계", ja: "シーズン合計", zh: "赛季总计"),
  "Match analysis could not be loaded.": (
    ko: "경기 분석을 불러오지 못했어요.",
    ja: "試合分析を読み込めませんでした。",
    zh: "无法加载比赛分析。"
  ),
  "Tactical analysis is unavailable for this match.": (
    ko: "이 경기의 전술 분석이 없어요.",
    ja: "この試合の戦術分析はありません。",
    zh: "暂无本场比赛的战术分析。"
  ),
  "Pitch values compare each team’s share of recoveries by third.": (
    ko: "경기장을 세 구역으로 나눠 팀별 볼 회수 비율을 비교해요.",
    ja: "ピッチを3分割し、各チームのボール回収率を比較します。",
    zh: "将球场分为三区，比较各队的球权夺回占比。"
  ),
  "Comment": (ko: "댓글", ja: "コメント", zh: "评论"),
  "Comments": (ko: "댓글", ja: "コメント", zh: "评论"),
  "Write a comment...": (ko: "댓글을 입력해 주세요…", ja: "コメントを入力…", zh: "写评论…"),
  "Write a reply...": (ko: "답글을 입력해 주세요…", ja: "返信を入力…", zh: "写回复…"),
  "Write something...": (ko: "내용을 입력해 주세요…", ja: "内容を入力…", zh: "写点什么…"),
  "Title...": (ko: "제목을 입력해 주세요…", ja: "タイトルを入力…", zh: "输入标题…"),
  "Title and body are required.": (
    ko: "제목과 내용을 입력해 주세요.",
    ja: "タイトルと本文を入力してください。",
    zh: "请输入标题和正文。"
  ),
  "Add photo or video": (ko: "사진 또는 동영상 추가", ja: "写真・動画を追加", zh: "添加照片或视频"),
  "You can attach up to {count} files.": (
    ko: "파일은 최대 {count}개까지 첨부할 수 있어요.",
    ja: "ファイルは{count}個まで添付できます。",
    zh: "最多可添加{count}个文件。"
  ),
  "Unable to add attachments. Please try again.": (
    ko: "파일을 첨부하지 못했어요. 다시 시도해 주세요.",
    ja: "ファイルを添付できませんでした。もう一度お試しください。",
    zh: "无法添加附件，请重试。"
  ),
  "Popular": (ko: "추천순", ja: "人気順", zh: "热门"),
  "Newest": (ko: "최신순", ja: "新しい順", zh: "最新"),
  "Latest": (ko: "최신", ja: "最新", zh: "最新"),
  "Best": (ko: "인기", ja: "人気", zh: "热门"),
  "No comments yet.": (ko: "아직 댓글이 없어요.", ja: "コメントはまだありません。", zh: "暂无评论。"),
  "No posts yet.": (ko: "아직 게시글이 없어요.", ja: "投稿はまだありません。", zh: "暂无帖子。"),
  "No notifications yet.": (ko: "아직 알림이 없어요.", ja: "通知はまだありません。", zh: "暂无通知。"),
  "Unable to load notifications.": (
    ko: "알림을 불러올 수 없어요.",
    ja: "通知を読み込めません。",
    zh: "无法加载通知。"
  ),
  "Unable to load post.": (
    ko: "게시글을 불러올 수 없어요.",
    ja: "投稿を読み込めません。",
    zh: "无法加载帖子。"
  ),
  "Try again": (ko: "다시 시도", ja: "再試行", zh: "重试"),
  "Unable to load comments.": (
    ko: "댓글을 불러오지 못했어요.",
    ja: "コメントを読み込めませんでした。",
    zh: "无法加载评论。"
  ),
  "Unable to post comment. Please try again.": (
    ko: "댓글을 올리지 못했어요. 다시 시도해 주세요.",
    ja: "コメントを投稿できませんでした。もう一度お試しください。",
    zh: "无法发布评论，请重试。"
  ),
  "Unable to publish post. Please try again.": (
    ko: "게시글을 올리지 못했어요. 다시 시도해 주세요.",
    ja: "投稿できませんでした。もう一度お試しください。",
    zh: "无法发布帖子，请重试。"
  ),
  "Unable to load community posts.": (
    ko: "게시글을 불러오지 못했어요.",
    ja: "投稿を読み込めませんでした。",
    zh: "无法加载帖子。"
  ),
  "Unable to share post. Please try again.": (
    ko: "게시물을 공유하지 못했어요. 다시 시도해 주세요.",
    ja: "投稿を共有できませんでした。もう一度お試しください。",
    zh: "无法分享帖子，请重试。"
  ),
  "Unable to update like. Please try again.": (
    ko: "좋아요를 변경하지 못했어요. 다시 시도해 주세요.",
    ja: "いいねを更新できませんでした。もう一度お試しください。",
    zh: "无法更新点赞，请重试。"
  ),
  "More options": (ko: "더 보기", ja: "その他", zh: "更多选项"),
  "Load more": (ko: "더 보기", ja: "もっと見る", zh: "加载更多"),
  "Edit": (ko: "수정", ja: "編集", zh: "编辑"),
  "Edit post": (ko: "게시물 수정", ja: "投稿を編集", zh: "编辑帖子"),
  "Edit comment": (ko: "댓글 수정", ja: "コメントを編集", zh: "编辑评论"),
  "Updated {time}": (ko: "{time}에 수정됨", ja: "{time}に更新", zh: "{time}更新"),
  "Unable to load updated post. Please try again.": (
    ko: "수정된 게시물을 불러오지 못했어요. 다시 시도해 주세요.",
    ja: "編集した投稿を読み込めませんでした。もう一度お試しください。",
    zh: "无法加载更新后的帖子，请重试。"
  ),
  "Unable to update post. Please try again.": (
    ko: "게시물을 수정하지 못했어요. 다시 시도해 주세요.",
    ja: "投稿を編集できませんでした。もう一度お試しください。",
    zh: "无法更新帖子，请重试。"
  ),
  "Unable to update comment. Please try again.": (
    ko: "댓글을 수정하지 못했어요. 다시 시도해 주세요.",
    ja: "コメントを編集できませんでした。もう一度お試しください。",
    zh: "无法更新评论，请重试。"
  ),
  "Delete": (ko: "삭제", ja: "削除", zh: "删除"),
  "Delete post?": (ko: "게시물을 삭제할까요?", ja: "投稿を削除しますか？", zh: "删除帖子吗？"),
  "Delete comment?": (ko: "댓글을 삭제할까요?", ja: "コメントを削除しますか？", zh: "删除评论吗？"),
  "This cannot be undone.": (
    ko: "삭제하면 되돌릴 수 없어요.",
    ja: "削除すると元に戻せません。",
    zh: "删除后无法撤销。"
  ),
  "Unable to delete post. Please try again.": (
    ko: "게시물을 삭제하지 못했어요. 다시 시도해 주세요.",
    ja: "投稿を削除できませんでした。もう一度お試しください。",
    zh: "无法删除帖子，请重试。"
  ),
  "Unable to delete comment. Please try again.": (
    ko: "댓글을 삭제하지 못했어요. 다시 시도해 주세요.",
    ja: "コメントを削除できませんでした。もう一度お試しください。",
    zh: "无法删除评论，请重试。"
  ),
  "Deleted user": (ko: "탈퇴한 사용자", ja: "退会したユーザー", zh: "已注销用户"),
  "Blocked user": (ko: "차단한 사용자", ja: "ブロックしたユーザー", zh: "已屏蔽用户"),
  "Deleted comment": (ko: "삭제된 댓글", ja: "削除されたコメント", zh: "已删除评论"),
  "Hidden comment": (ko: "숨겨진 댓글", ja: "非表示のコメント", zh: "已隐藏评论"),
  "This comment was deleted.": (
    ko: "삭제된 댓글이에요.",
    ja: "このコメントは削除されました。",
    zh: "这条评论已被删除。"
  ),
  "This comment is unavailable.": (
    ko: "볼 수 없는 댓글이에요.",
    ja: "このコメントは表示できません。",
    zh: "无法查看这条评论。"
  ),
  "Comment from a blocked user.": (
    ko: "차단한 사용자의 댓글이에요.",
    ja: "ブロックしたユーザーのコメントです。",
    zh: "这是来自已屏蔽用户的评论。"
  ),
  "Copy Text": (ko: "텍스트 복사", ja: "テキストをコピー", zh: "复制文本"),
  "Report": (ko: "신고", ja: "報告", zh: "举报"),
  "Inappropriate Content": (ko: "부적절한 콘텐츠", ja: "不適切なコンテンツ", zh: "不当内容"),
  "Harassment & Bullying": (ko: "괴롭힘 및 따돌림", ja: "嫌がらせ・いじめ", zh: "骚扰与霸凌"),
  "Spam": (ko: "스팸", ja: "スパム", zh: "垃圾信息"),
  "Advertising": (ko: "광고", ja: "広告", zh: "广告"),
  "Something Else": (ko: "기타", ja: "その他", zh: "其他"),
  "Thanks for your report!": (
    ko: "신고해 주셔서 감사해요!",
    ja: "ご報告ありがとうございます！",
    zh: "感谢你的举报！"
  ),
  "Thanks again for your report — we’ve got your back, and your fellow 1touchers too. Every report helps make 1touch a safer, better place for everyone.":
      (
    ko: "신고 내용을 확인할게요. 보내주신 신고는 모두가 안전하게 1touch를 이용하는 데 도움이 돼요.",
    ja: "ご報告を確認します。皆さまのご協力が、安心して1touchを利用できる環境づくりにつながります。",
    zh: "我们会核查举报内容。你的每一次举报都能帮助大家更安全地使用1touch。"
  ),
  "Unable to submit report. Please try again.": (
    ko: "신고를 보내지 못했어요. 다시 시도해 주세요.",
    ja: "報告を送信できませんでした。もう一度お試しください。",
    zh: "无法提交举报，请重试。"
  ),
  "Community Ground Rules": (ko: "커뮤니티 이용 약속", ja: "コミュニティのルール", zh: "社区公约"),
  "Keep it about football": (
    ko: "의견이 달라도 서로 존중해요",
    ja: "意見が違っても、お互いを尊重しましょう",
    zh: "即使意见不同，也请互相尊重",
  ),
  "Disagree with the take, not the person.": (
    ko: "생각이 달라도 상대방을 공격하지 말고, 의견으로 이야기해주세요.",
    ja: "考えが違っても、相手を攻撃せず、意見そのものについて話してください。",
    zh: "想法不同没关系。请围绕观点本身交流，不要攻击他人。",
  ),
  "Respect the players": (
    ko: "선수를 존중해요",
    ja: "選手を尊重しましょう",
    zh: "请尊重球员",
  ),
  "Talk about mistakes and performances without making it personal.": (
    ko: "플레이와 경기력에 대한 의견은 자유롭게 나눠주세요. 선수 개인을 향한 모욕이나 인신공격은 삼가 주세요.",
    ja: "プレーやパフォーマンスについては自由に意見を交わしてください。選手個人への侮辱や人格攻撃は控えてください。",
    zh: "可以自由讨论球员的表现和比赛发挥。请不要侮辱球员，也不要进行人身攻击。",
  ),
  "Rivalries are part of the fun": (
    ko: "응원하는 팀이 달라도 괜찮아요",
    ja: "応援するチームが違っても大丈夫です",
    zh: "支持不同的球队也没关系",
  ),
  "Banter and friendly rivalry are welcome. Keep it fun and respectful.": (
    ko: "놀리고 티격태격하는 것도 축구의 재미예요. 팀이나 팬을 깎아내리는 말은 피해 주세요.",
    ja: "軽いからかいやライバル同士のやり取りも、サッカーの楽しみのひとつです。楽しく、相手への敬意は忘れないでください。",
    zh: "互相调侃、友好较劲也是足球的乐趣之一。请保持轻松，也尊重彼此。",
  ),
  "Keep the space safe": (
    ko: "모두가 편하게 볼 수 있는 글을 올려요",
    ja: "みんなが安心して読める投稿をしましょう",
    zh: "请发布让大家都能安心阅读的内容",
  ),
  "Avoid spam, hate or discriminatory speech, promotional posts, and suspicious links.":
      (
    ko: "도배, 혐오·차별 표현, 광고성 글, 수상한 링크는 올리지 말아 주세요.",
    ja: "スパム投稿、ヘイト・差別的な表現、宣伝目的の投稿、不審なリンクは投稿しないでください。",
    zh: "请不要刷屏、发表仇恨或歧视性言论、发布广告内容或可疑链接。",
  ),
  "Add to the atmosphere": (
    ko: "좋은 분위기를 함께 만들어요",
    ja: "みんなでいい雰囲気をつくりましょう",
    zh: "一起营造良好的氛围",
  ),
  "Cheer, debate, and joke around. Be considerate and help keep the community welcoming.":
      (
    ko: "응원하고, 토론하고, 농담도 나눠주세요. 서로를 배려하며 좋은 분위기를 만들어주세요.",
    ja: "応援したり、議論したり、冗談を言い合ったりしながら楽しんでください。お互いに配慮し、気持ちのいいコミュニティを一緒につくってください。",
    zh: "欢迎一起加油、讨论、开玩笑。请彼此体谅，一起营造友好的社区氛围。",
  ),
  "I UNDERSTAND!": (ko: "이해했습니다!", ja: "理解しました！", zh: "我明白了！"),
  "TEMPORARILY SUSPENDED": (
    ko: "지금은 커뮤니티를 이용할 수 없어요",
    ja: "現在、コミュニティを利用できません",
    zh: "目前无法使用社区",
  ),
  "Your access to the community has been restricted for {reason}.": (
    ko: "{reason} 커뮤니티 이용이 제한됐어요.",
    ja: "{reason}ため、コミュニティの利用が制限されています。",
    zh: "因{reason}，你的社区使用权限已被限制。",
  ),
  "Your access to the community has been restricted.": (
    ko: "커뮤니티 이용이 제한됐어요.",
    ja: "コミュニティの利用が制限されています。",
    zh: "你的社区使用权限已被限制。",
  ),
  // 사유를 완성된 문장으로 바꾸면 위 문장 틀과 자연스럽게 이어지지 않아요.
  "harassing or insulting other users": (
    ko: "다른 이용자를 괴롭히거나 비방해",
    ja: "他のユーザーに嫌がらせをしたり、誹謗中傷した",
    zh: "骚扰或辱骂其他用户",
  ),
  "using hate speech": (
    ko: "혐오 표현을 사용해",
    ja: "ヘイトスピーチを使用した",
    zh: "使用仇恨言论",
  ),
  "using violent or threatening language": (
    ko: "폭력적인 표현을 사용하거나 위협해",
    ja: "暴力的な表現を使用したり、脅迫した",
    zh: "使用暴力或威胁性言论",
  ),
  "repeatedly posting spam": (
    ko: "스팸이나 도배를 반복해",
    ja: "スパムや連投を繰り返した",
    zh: "反复发布垃圾信息或刷屏",
  ),
  "disrupting community activity": (
    ko: "커뮤니티 활동을 방해해",
    ja: "コミュニティ活動を妨害した",
    zh: "干扰社区正常活动",
  ),
  "sharing someone else’s personal information": (
    ko: "다른 사람의 개인정보를 공개해",
    ja: "他人の個人情報を公開した",
    zh: "公开他人的个人信息",
  ),
  "posting inappropriate content": (
    ko: "부적절한 콘텐츠를 게시해",
    ja: "不適切なコンテンツを投稿した",
    zh: "发布不当内容",
  ),
  "posting content that may be harmful to minors": (
    ko: "미성년자에게 유해한 콘텐츠를 게시해",
    ja: "未成年者に有害なコンテンツを投稿した",
    zh: "发布可能对未成年人有害的内容",
  ),
  "impersonating another person or organization or misleading others": (
    ko: "다른 사람이나 단체를 사칭하거나 속여",
    ja: "他人や団体になりすましたり、他者を欺いた",
    zh: "冒充他人或组织，或欺骗其他用户",
  ),
  "posting or trading illegal content": (
    ko: "불법 콘텐츠를 게시하거나 거래해",
    ja: "違法なコンテンツを投稿または取引した",
    zh: "发布或交易非法内容",
  ),
  "misusing the service": (
    ko: "서비스를 악용해",
    ja: "サービスを不正利用した",
    zh: "滥用服务",
  ),
  "violating the Community Guidelines": (
    ko: "커뮤니티 이용규칙을 위반해",
    ja: "コミュニティガイドラインに違反した",
    zh: "违反社区准则",
  ),
  "You’ll be able to use the community again when the time above runs out.": (
    ko: "남은 시간이 지나면 다시 이용할 수 있어요.",
    ja: "残り時間がなくなると、また利用できます。",
    zh: "剩余时间结束后，就可以再次使用社区。",
  ),
  "Close": (ko: "닫기", ja: "閉じる", zh: "关闭"),
  "Please read the rules for 10 seconds before continuing.": (
    ko: "이용 금지 조치 이후 복귀한 유저들은 10초 동안 이용수칙을 정독해주세요.",
    ja: "利用停止後に戻った方は、10秒間ルールをお読みください。",
    zh: "限制结束后，请阅读社区规则10秒再继续。",
  ),
  "I understand": (ko: "이해했어요", ja: "理解しました", zh: "我明白了"),
  "Unable to load community rules.": (
    ko: "커뮤니티 이용 규칙을 불러오지 못했어요.",
    ja: "コミュニティルールを読み込めませんでした。",
    zh: "无法加载社区规则。"
  ),
  "LIVE CHAT": (ko: "실시간 채팅", ja: "ライブチャット", zh: "实时聊天"),
  "Type a message": (ko: "메시지를 입력해 주세요", ja: "メッセージを入力", zh: "输入消息"),
  "Be the first to chat!": (
    ko: "첫 메시지를 남겨보세요!",
    ja: "最初のメッセージを送りましょう！",
    zh: "发送第一条消息吧！"
  ),
  "Couldn't connect to chat": (
    ko: "채팅에 연결하지 못했어요",
    ja: "チャットに接続できませんでした",
    zh: "无法连接聊天"
  ),
  "Chat disconnected. Please try again.": (
    ko: "채팅 연결이 끊겼어요. 다시 시도해 주세요.",
    ja: "チャットが切断されました。もう一度お試しください。",
    zh: "聊天已断开，请重试。"
  ),
  "Chat unavailable": (ko: "지금은 채팅할 수 없어요", ja: "現在チャットは利用できません", zh: "当前无法聊天"),
  "Live chat is only available during the match.": (
    ko: "경기 중에만 실시간 채팅을 이용할 수 있어요.",
    ja: "ライブチャットは試合中のみ利用できます。",
    zh: "仅可在比赛进行时使用实时聊天。"
  ),
  "Chat is only available to supporters of the participating teams.": (
    ko: "경기에 참여한 팀의 팬만 채팅할 수 있어요.",
    ja: "対戦チームのサポーターのみチャットに参加できます。",
    zh: "仅对阵球队的支持者可参与聊天。"
  ),
  "Just now": (ko: "방금 전", ja: "たった今", zh: "刚刚"),
  "{count}m ago": (ko: "{count}분 전", ja: "{count}分前", zh: "{count}分钟前"),
  "{count}h ago": (ko: "{count}시간 전", ja: "{count}時間前", zh: "{count}小时前"),
  "{count}d ago": (ko: "{count}일 전", ja: "{count}日前", zh: "{count}天前"),
  "{count} minutes ago": (ko: "{count}분 전", ja: "{count}分前", zh: "{count}分钟前"),
  "{count} hours ago": (ko: "{count}시간 전", ja: "{count}時間前", zh: "{count}小时前"),
  "{count} days ago": (ko: "{count}일 전", ja: "{count}日前", zh: "{count}天前"),
  "Today": (ko: "오늘", ja: "今日", zh: "今天"),
  "Yesterday": (ko: "어제", ja: "昨日", zh: "昨天"),
  "Last week": (ko: "지난주", ja: "先週", zh: "上周"),
  "{count} weeks ago": (ko: "{count}주 전", ja: "{count}週間前", zh: "{count}周前"),
  "Reactions": (ko: "반응", ja: "リアクション", zh: "互动"),
  "Match Reminder": (ko: "경기 알림", ja: "試合リマインダー", zh: "比赛提醒"),
  "Kickoff, Half Time, Full Time": (
    ko: "킥오프, 전반 종료, 경기 종료",
    ja: "キックオフ・前半終了・試合終了",
    zh: "开球、半场、全场"
  ),
  "New bets": (ko: "새 베팅", ja: "新しい予想", zh: "新竞猜"),
  "New Bet Available": (ko: "새 베팅이 열렸어요", ja: "新しい予想が可能です", zh: "新的竞猜已开放"),
  "Post-match Result": (ko: "경기 결과", ja: "試合結果", zh: "赛后结果"),
  "APPLY TO ALL PLAYERS": (ko: "모든 선수에 적용하기", ja: "すべての選手に適用", zh: "应用到所有球员"),
  "APPLY TO ALL TEAMS": (ko: "모든 팀에 적용하기", ja: "すべてのチームに適用", zh: "应用到所有球队"),
  "Applied to all following players": (
    ko: "팔로우한 모든 선수에 적용했어요",
    ja: "フォロー中の全選手に適用しました",
    zh: "已应用到所有关注的球员"
  ),
  "Applied to all following teams": (
    ko: "팔로우한 모든 팀에 적용했어요",
    ja: "フォロー中の全チームに適用しました",
    zh: "已应用到所有关注的球队"
  ),
  "Done": (ko: "완료", ja: "完了", zh: "完成"),
  "Sync all upcoming matches for {team}. Each event lasts 2 hours, with a reminder 30 minutes before kickoff.":
      (
    ko: "{team}의 전체 예정 경기를 동기화해요. 경기당 2시간으로 저장하고 시작 30분 전에 알려드려요.",
    ja: "{team}の今後の全試合を同期します。各予定は2時間で、開始30分前に通知します。",
    zh: "同步{team}的所有未来比赛。每场按2小时保存，并在开赛前30分钟提醒。"
  ),
  "Connected to the 1touch calendar in Google. Match changes will update even when this app is closed.":
      (
    ko: "Google의 1touch 캘린더에 연결했어요. 앱을 닫아도 변경된 경기 일정을 자동으로 반영해요.",
    ja: "Googleの1touchカレンダーに接続しました。アプリを閉じていても試合日程の変更を自動で反映します。",
    zh: "已连接Google中的1touch日历。即使关闭本应用，赛程变更也会自动更新。"
  ),
  "Finish subscribing in Calendar and enable event alerts. Apple controls when subscription changes appear.":
      (
    ko: "캘린더 앱에서 구독을 완료하고 이벤트 알림을 켜 주세요. 변경된 일정의 반영 시점은 Apple의 갱신 주기를 따라요.",
    ja: "カレンダーで登録を完了し、予定の通知をオンにしてください。変更の反映時期はAppleの更新間隔に従います。",
    zh: "请在日历中完成订阅并开启日程提醒。变更会按Apple的刷新周期更新。"
  ),
  "Automatic sync for this team has stopped. Upcoming events shared with another synced team will remain.":
      (
    ko: "이 팀의 자동 동기화를 해제했어요. 동기화 중인 다른 팀과 겹치는 예정 경기는 남겨뒀어요.",
    ja: "このチームの自動同期を停止しました。他の同期中のチームと共通する予定は残ります。",
    zh: "已停止此球队的自动同步。与其他已同步球队共有的未来比赛将保留。"
  ),
  "Google Calendar disconnected. Automatic updates have stopped.": (
    ko: "Google 캘린더 연결을 해제했어요. 자동 갱신을 중단했어요.",
    ja: "Googleカレンダーの接続を解除し、自動更新を停止しました。",
    zh: "已断开Google日历连接并停止自动更新。"
  ),
  "Calendar sync is available on iPhone and Android.": (
    ko: "캘린더 동기화는 아이폰과 안드로이드에서 사용할 수 있어요.",
    ja: "カレンダー同期はiPhoneとAndroidで利用できます。",
    zh: "日历同步仅支持iPhone和Android。"
  ),
  "Calendar connection cancelled.": (
    ko: "캘린더 연결을 취소했어요.",
    ja: "カレンダー接続をキャンセルしました。",
    zh: "已取消日历连接。"
  ),
  "Could not connect to Google. Please try again.": (
    ko: "Google에 연결하지 못했어요. 다시 시도해 주세요.",
    ja: "Googleに接続できませんでした。もう一度お試しください。",
    zh: "无法连接Google，请重试。"
  ),
  "Choose the Google account already connected to 1touch.": (
    ko: "1touch에 이미 연결한 Google 계정을 선택해 주세요.",
    ja: "1touchに接続済みのGoogleアカウントを選択してください。",
    zh: "请选择已连接1touch的Google账号。"
  ),
  "Allow 1touch to manage its calendar, then try again.": (
    ko: "1touch 캘린더 관리 권한을 허용하고 다시 시도해 주세요.",
    ja: "1touchのカレンダー管理を許可してから、もう一度お試しください。",
    zh: "请允许1touch管理其日历，然后重试。"
  ),
  "Google calendar access expired. Please connect again.": (
    ko: "Google 캘린더 접근 권한이 만료됐어요. 다시 연결해 주세요.",
    ja: "Googleカレンダーへのアクセスが期限切れです。再接続してください。",
    zh: "Google日历访问权限已过期，请重新连接。"
  ),
  "The 1touch calendar was removed. Connect again to create it.": (
    ko: "1touch 캘린더가 삭제됐어요. 다시 연결하면 새로 만들어요.",
    ja: "1touchカレンダーが削除されました。再接続すると作成されます。",
    zh: "1touch日历已被删除。重新连接即可创建。"
  ),
  "Could not load the calendar subscription. Please try again.": (
    ko: "캘린더 구독 정보를 불러오지 못했어요. 다시 시도해 주세요.",
    ja: "カレンダーの登録情報を読み込めませんでした。もう一度お試しください。",
    zh: "无法加载日历订阅，请重试。"
  ),
  "Could not open Calendar. Please try again on your iPhone.": (
    ko: "캘린더 앱을 열지 못했어요. 아이폰에서 다시 시도해 주세요.",
    ja: "カレンダーを開けませんでした。iPhoneでもう一度お試しください。",
    zh: "无法打开日历，请在iPhone上重试。"
  ),
  "Calendar sync could not finish. Please try again.": (
    ko: "캘린더 동기화를 완료하지 못했어요. 다시 시도해 주세요.",
    ja: "カレンダーの同期を完了できませんでした。もう一度お試しください。",
    zh: "未能完成日历同步，请重试。"
  ),
  "Disconnect Google Calendar?": (
    ko: "Google 캘린더 연결을 해제할까요?",
    ja: "Googleカレンダーの接続を解除しますか？",
    zh: "要断开Google日历连接吗？"
  ),
  "Automatic updates for all teams will stop. Saved events will remain in Google Calendar.":
      (
    ko: "모든 팀의 자동 갱신을 중단해요. 이미 저장된 일정은 Google 캘린더에 남아요.",
    ja: "全チームの自動更新を停止します。保存済みの予定はGoogleカレンダーに残ります。",
    zh: "所有球队将停止自动更新。已保存的日程将保留在Google日历中。"
  ),
  "Disconnect": (ko: "연결 해제", ja: "接続を解除", zh: "断开连接"),
  "Stop syncing this team": (
    ko: "이 팀 동기화 해제",
    ja: "このチームの同期を停止",
    zh: "停止同步此球队"
  ),
  "Upcoming events for this team will be removed from the 1touch calendar.": (
    ko: "이 팀의 예정 경기를 1touch 캘린더에서 삭제해요.",
    ja: "このチームの今後の予定を1touchカレンダーから削除します。",
    zh: "此球队的未来比赛将从1touch日历中删除。"
  ),
  "Disconnect Google Calendar": (
    ko: "Google 캘린더 연결 해제",
    ja: "Googleカレンダーの接続を解除",
    zh: "断开Google日历连接"
  ),
  "Sync with your calendar?": (
    ko: "캘린더와 동기화할까요?",
    ja: "カレンダーと同期しますか？",
    zh: "要同步到日历吗？"
  ),
  "We’ll add your favorite team’s upcoming matches straight to your calendar, so you never miss a kickoff. You’ll get notified before each game — no spam, no surprises.":
      (
    ko: "좋아하는 팀의 경기 일정을 캘린더에 추가해 드려요. 경기를 놓치지 않도록 시작 전에 알려드릴게요.",
    ja: "お気に入りチームの試合をカレンダーに追加します。キックオフを見逃さないよう、試合前にお知らせします。",
    zh: "将你喜欢的球队赛程添加到日历，并在赛前提醒你，不错过每一次开球。"
  ),
  "YES, SYNC IT!": (ko: "네, 동기화할게요", ja: "同期する", zh: "立即同步"),
  "PLACE A BET": (ko: "베팅하기", ja: "予想する", zh: "参与竞猜"),
  "CONFIRM BET": (ko: "베팅 확정", ja: "予想を確定", zh: "确认竞猜"),
  "EDIT BET": (ko: "베팅 수정", ja: "予想を編集", zh: "修改竞猜"),
  "CANCEL BET": (ko: "베팅 취소", ja: "予想をキャンセル", zh: "取消竞猜"),
  "KEEP BET": (ko: "베팅 유지", ja: "予想を維持", zh: "保留竞猜"),
  "CHANGE PICK": (ko: "선택 변경", ja: "選択を変更", zh: "更改选择"),
  "Cancel your bet?": (ko: "베팅을 취소할까요?", ja: "予想をキャンセルしますか？", zh: "要取消竞猜吗？"),
  "Bet Submitted!": (ko: "베팅을 완료했어요!", ja: "予想を送信しました！", zh: "竞猜已提交！"),
  "SUBMIT": (ko: "제출", ja: "送信", zh: "提交"),
  "SUBMITTING…": (ko: "제출 중…", ja: "送信中…", zh: "提交中…"),
  "HISTORY": (ko: "내역", ja: "履歴", zh: "记录"),
  "REFRESH RESULT": (ko: "결과 새로고침", ja: "結果を更新", zh: "刷新结果"),
  "Waiting for the result": (ko: "결과를 기다리고 있어요", ja: "結果を待っています", zh: "等待结果"),
  "Check back after the final whistle for the result.": (
    ko: "경기 종료 후 결과를 확인해 주세요.",
    ja: "試合終了後に結果をご確認ください。",
    zh: "请在比赛结束后查看结果。"
  ),
  "No bets yet.": (ko: "아직 베팅 내역이 없어요.", ja: "予想の履歴はまだありません。", zh: "暂无竞猜记录。"),
  "Unable to load bets.": (
    ko: "베팅 내역을 불러오지 못했어요.",
    ja: "予想の履歴を読み込めませんでした。",
    zh: "无法加载竞猜记录。"
  ),
  "Unable to load or save your bet. Please try again.": (
    ko: "베팅을 불러오거나 저장하지 못했어요. 다시 시도해 주세요.",
    ja: "予想の読み込み・保存ができませんでした。もう一度お試しください。",
    zh: "无法加载或保存竞猜，请重试。"
  ),
  "Betting is available for supported league matches.": (
    ko: "지원하는 리그 경기에서 베팅할 수 있어요.",
    ja: "対応リーグの試合で予想できます。",
    zh: "可参与支持联赛的比赛竞猜。"
  ),
  "Betting is closed for this match.": (
    ko: "이 경기의 베팅이 마감됐어요.",
    ja: "この試合の予想受付は終了しました。",
    zh: "本场比赛竞猜已截止。"
  ),
  "Betting opens when the kickoff is confirmed.": (
    ko: "킥오프 시간이 확정되면 베팅이 열려요.",
    ja: "キックオフ時間が決まると予想受付が始まります。",
    zh: "开球时间确定后将开放竞猜。"
  ),
  "Betting opens {date}.": (
    ko: "{date}에 베팅이 열려요.",
    ja: "{date}に予想受付が始まります。",
    zh: "竞猜将于{date}开放。"
  ),
  "Not enough points.": (ko: "포인트가 부족해요.", ja: "ポイントが足りません。", zh: "积分不足。"),
  "You need at least {points} pts to place a bet.": (
    ko: "베팅하려면 최소 {points}포인트가 필요해요.",
    ja: "予想には最低{points}ポイントが必要です。",
    zh: "参与竞猜至少需要{points}积分。"
  ),
  "Sign in to use points.": (
    ko: "포인트를 사용하려면 로그인해 주세요.",
    ja: "ポイントを使うにはログインしてください。",
    zh: "请登录以使用积分。"
  ),
  "Odds have changed. Review them and submit again.": (
    ko: "배당이 바뀌었어요. 확인 후 다시 제출해 주세요.",
    ja: "オッズが変わりました。確認して再送信してください。",
    zh: "赔率已更新，请确认后重新提交。"
  ),
  "Your bet has changed. Review it and try again.": (
    ko: "베팅 내용이 바뀌었어요. 확인 후 다시 시도해 주세요.",
    ja: "予想内容が変わりました。確認して再度お試しください。",
    zh: "竞猜内容已更改，请确认后重试。"
  ),
  "Not correct · 0 pts returned": (
    ko: "적중 실패 · 반환 0포인트",
    ja: "不的中 · 0ポイント返還",
    zh: "未猜中 · 返还0积分"
  ),
  "You're on the bench for a moment": (
    ko: "잠시 벤치에서 쉬어가요",
    ja: "少しベンチでひと休み",
    zh: "暂时在替补席休息一下"
  ),
  "The page could not be found.": (
    ko: "찾고 있는 페이지를 찾을 수 없어요.",
    ja: "お探しのページが見つかりません。",
    zh: "找不到你要访问的页面。"
  ),
  "You don't have permission to access this page.": (
    ko: "이 페이지에 접근할 권한이 없어요.",
    ja: "このページにアクセスする権限がありません。",
    zh: "你无权访问此页面。"
  ),
  "Too many requests. Please try again later.": (
    ko: "요청이 너무 많아요. 잠시 후 다시 시도해주세요.",
    ja: "リクエストが多すぎます。しばらくしてからお試しください。",
    zh: "请求过多，请稍后重试。"
  ),
  "The server is taking too long to respond. Please try again.": (
    ko: "서버 응답이 지연되고 있어요. 다시 시도해주세요.",
    ja: "サーバーの応答が遅れています。もう一度お試しください。",
    zh: "服务器响应超时，请重试。"
  ),
  "There is a server problem. Please try again later.": (
    ko: "서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요.",
    ja: "サーバーに問題が発生しました。しばらくしてからお試しください。",
    zh: "服务器出现问题，请稍后重试。"
  ),
  "The service is currently unavailable. Please try again later.": (
    ko: "현재 서비스를 이용할 수 없어요. 잠시 후 다시 시도해주세요.",
    ja: "現在サービスを利用できません。しばらくしてからお試しください。",
    zh: "服务暂不可用，请稍后重试。"
  ),
  "Servers could not connect. Please try again later.": (
    ko: "서버 간 연결에 문제가 생겼어요. 잠시 후 다시 시도해주세요.",
    ja: "サーバー間の接続に問題があります。しばらくしてからお試しください。",
    zh: "服务器间连接出现问题，请稍后重试。"
  ),
  "Go home": (ko: "홈으로", ja: "ホームへ", zh: "返回首页"),
  "Go back": (ko: "돌아가기", ja: "戻る", zh: "返回"),
  "Sign in again": (ko: "다시 로그인", ja: "再ログイン", zh: "重新登录"),
  "Please join again": (ko: "다시 입장해주세요", ja: "もう一度参加してください", zh: "请重新加入"),
  "Pass incomplete": (ko: "패스 연결에 실패했어요", ja: "パスがつながりませんでした", zh: "传球未成功"),
  "Beyond added time": (ko: "추가시간을 넘겼어요", ja: "追加時間を過ぎました", zh: "已超出补时时间"),
  "Offside!": (ko: "오프사이드!", ja: "オフサイド！", zh: "越位！"),
  "Red card!": (ko: "레드카드!", ja: "レッドカード！", zh: "红牌！"),
  "Match interrupted": (ko: "잠시 경기 중단", ja: "試合が一時中断しています", zh: "比赛暂时中断"),
  "VAR check": (ko: "VAR 확인 중", ja: "VAR確認中", zh: "VAR检查中"),
  "Coming soon": (ko: "아직 준비 중이에요", ja: "準備中です", zh: "敬请期待"),
  "SWITCH": (ko: "선택한 팀으로 바꾸기", ja: "切り替え", zh: "切换"),
  "Ad": (ko: "광고", ja: "広告", zh: "广告"),
  "USER": (ko: "사용자", ja: "ユーザー", zh: "用户"),
  "January": (ko: "1월", ja: "1月", zh: "1月"),
  "February": (ko: "2월", ja: "2月", zh: "2月"),
  "March": (ko: "3월", ja: "3月", zh: "3月"),
  "April": (ko: "4월", ja: "4月", zh: "4月"),
  "May": (ko: "5월", ja: "5月", zh: "5月"),
  "June": (ko: "6월", ja: "6月", zh: "6月"),
  "July": (ko: "7월", ja: "7月", zh: "7月"),
  "August": (ko: "8월", ja: "8月", zh: "8月"),
  "September": (ko: "9월", ja: "9月", zh: "9月"),
  "October": (ko: "10월", ja: "10月", zh: "10月"),
  "November": (ko: "11월", ja: "11月", zh: "11月"),
  "December": (ko: "12월", ja: "12月", zh: "12月"),
  "By clicking sign up, I hereby agree and consent to\n1touch’s Terms & Conditions; I confirm that I have\nread 1touch’s Privacy Policy.":
      (
    ko: "회원가입을 누르면 1touch 이용약관에 동의하고\n개인정보 처리방침을 확인한 것으로 간주해요.",
    ja: "新規登録を押すと、1touchの利用規約に同意し、\nプライバシーポリシーを確認したものとみなします。",
    zh: "点击注册即表示同意1touch服务条款，\n并确认已阅读隐私政策。"
  ),
  "Unable to load attributes. Retry": (
    ko: "능력치를 불러오지 못했어요. 다시 시도",
    ja: "能力を読み込めませんでした。再試行",
    zh: "无法加载能力值，请重试"
  ),
  "Unable to load standings. Retry": (
    ko: "순위표를 불러오지 못했어요. 다시 시도",
    ja: "順位表を読み込めませんでした。再試行",
    zh: "无法加载积分榜，请重试"
  ),
  "Round {round}": (ko: "{round}라운드", ja: "第{round}節", zh: "第{round}轮"),
  "{leg} Leg": (ko: "{leg}차전", ja: "第{leg}戦", zh: "第{leg}回合"),
  "{points} Pts": (ko: "승점 {points}", ja: "勝点{points}", zh: "{points}积分"),
  "{points} pts": (ko: "{points}포인트", ja: "{points}ポイント", zh: "{points}积分"),
  "{points} points": (ko: "{points}포인트", ja: "{points}ポイント", zh: "{points}积分"),
  "You earned {points} from this bet! 🎉": (
    ko: "이 베팅으로 {points}를 획득했어요! 🎉",
    ja: "このベットで{points}獲得しました！🎉",
    zh: "你从这次投注中赢得了{points}！🎉"
  ),
  "You used {stake} pts · {return} pts if correct": (
    ko: "{stake}포인트 사용 · 적중 시 {return}포인트",
    ja: "{stake}ポイント使用 · 的中時{return}ポイント",
    zh: "使用{stake}积分 · 猜中可得{return}积分"
  ),
  "You earned no points from this bet.": (
    ko: "이 베팅에서 획득한 포인트가 없어요.",
    ja: "このベットで獲得したポイントはありません。",
    zh: "这次投注没有赢得积分。"
  ),
  "{points} were refunded from this bet.": (
    ko: "이 베팅에서 {points}를 환불받았어요.",
    ja: "このベットから{points}払い戻されました。",
    zh: "这次投注已退还{points}。"
  ),
  "You’ve got {points} pts!": (
    ko: "{points}포인트가 있어요!",
    ja: "{points}ポイントあります！",
    zh: "你有{points}积分！"
  ),
  "{points} pts will be returned.": (
    ko: "{points}포인트가 반환돼요.",
    ja: "{points}ポイントが返還されます。",
    zh: "将返还{points}积分。"
  ),
  "Available: {points} pts": (
    ko: "사용 가능: {points}포인트",
    ja: "利用可能：{points}ポイント",
    zh: "可用：{points}积分"
  ),
  "If correct: +{points} pts": (
    ko: "적중 시: +{points}포인트",
    ja: "的中時：+{points}ポイント",
    zh: "猜中后：+{points}积分"
  ),
  "Total return: {points} pts, including your stake.": (
    ko: "베팅 포인트를 포함해 총 {points}포인트를 돌려받아요.",
    ja: "賭けたポイントを含め、合計{points}ポイントが返還されます。",
    zh: "包含投入积分在内，共返还{points}积分。"
  ),
  "{count} participants": (
    ko: "{count}명 참여",
    ja: "{count}人参加",
    zh: "{count}人参与"
  ),
  "Return if correct: {points} pts (includes stake)": (
    ko: "적중 시 반환: {points}포인트 (베팅 포인트 포함)",
    ja: "的中時の返還：{points}ポイント（賭け分を含む）",
    zh: "猜中后返还：{points}积分（包含投入积分）"
  ),
  "Won · {points} pts returned": (
    ko: "적중 · {points}포인트 반환",
    ja: "的中 · {points}ポイント返還",
    zh: "猜中 · 返还{points}积分"
  ),
  "Refunded · {points} pts returned": (
    ko: "환불 · {points}포인트 반환",
    ja: "払い戻し · {points}ポイント返還",
    zh: "已退款 · 返还{points}积分"
  ),
  "HOME {home}  •  AWAY {away}": (
    ko: "홈 {home}  •  원정 {away}",
    ja: "ホーム {home}  •  アウェイ {away}",
    zh: "主队 {home}  •  客队 {away}"
  ),
  "Match {number}": (ko: "{number}차전", ja: "第{number}戦", zh: "第{number}场"),
  "Replying to {name}": (
    ko: "{name}님에게 답글 남기는 중",
    ja: "{name}さんに返信中",
    zh: "正在回复{name}"
  ),
  "Select Player {slot}": (
    ko: "선수 {slot} 선택",
    ja: "選手{slot}を選択",
    zh: "选择球员{slot}"
  ),
  "PLAYER {slot}": (ko: "선수 {slot}", ja: "選手{slot}", zh: "球员{slot}"),
  "{age} yrs": (ko: "{age}세", ja: "{age}歳", zh: "{age}岁"),
  "{count} matches": (ko: "{count}경기", ja: "{count}試合", zh: "{count}场比赛"),
  "Tell us why you would like to report this {target}!": (
    ko: "이 {target}을 신고하는 이유를 알려주세요.",
    ja: "この{target}を報告する理由を教えてください。",
    zh: "请告诉我们举报此{target}的原因。"
  ),
  "post": (ko: "게시글", ja: "投稿", zh: "帖子"),
  "comment": (ko: "댓글", ja: "コメント", zh: "评论"),
  "Recovery comparison incomplete ({count} missing)": (
    ko: "볼 회수 비교 정보가 부족해요 ({count}명 누락)",
    ja: "ボール回収の比較情報が不足しています（{count}人分なし）",
    zh: "球权夺回对比信息不完整（缺少{count}人）"
  ),
  "{value} percentile": (
    ko: "백분위 {value}",
    ja: "{value}パーセンタイル",
    zh: "第{value}百分位"
  ),
  "Passes completed / attempted": (
    ko: "패스 성공 / 시도",
    ja: "パス成功 / 試行",
    zh: "传球成功 / 尝试"
  ),
  "Possession lost": (ko: "소유권 상실", ja: "ボールロスト", zh: "丢失球权"),
  "Ball recoveries": (ko: "볼 회수", ja: "ボール奪回", zh: "夺回球权"),
  "Long balls attempted": (ko: "롱패스 시도", ja: "ロングパス試行", zh: "长传尝试"),
  "Long ball success rate": (ko: "롱패스 성공률", ja: "ロングパス成功率", zh: "长传成功率"),
  "Duels won / contested": (
    ko: "경합 승리 / 시도",
    ja: "デュエル勝利 / 試行",
    zh: "对抗成功 / 尝试"
  ),
  "Aerial duels won": (ko: "공중볼 경합 승리", ja: "空中戦勝利", zh: "争顶成功"),
  "Dribbled past": (ko: "드리블 돌파 허용", ja: "被ドリブル突破", zh: "被过次数"),
  "Fouls committed": (ko: "파울", ja: "ファウル", zh: "犯规"),
  "Key passes": (ko: "키 패스", ja: "キーパス", zh: "关键传球"),
  "Passes in final third": (ko: "공격 지역 패스", ja: "アタッキングサードのパス", zh: "进攻三区传球"),
  "Total duels": (ko: "전체 경합", ja: "デュエル総数", zh: "总对抗次数"),
  "Fouls drawn": (ko: "얻어낸 파울", ja: "被ファウル", zh: "被犯规"),
  "Total shots": (ko: "전체 슈팅", ja: "シュート総数", zh: "总射门"),
  "Dribble attempts": (ko: "드리블 시도", ja: "ドリブル試行", zh: "盘带尝试"),
  "Dribble success rate": (ko: "드리블 성공률", ja: "ドリブル成功率", zh: "盘带成功率"),
  "Duels won": (ko: "경합 승리", ja: "デュエル勝利", zh: "对抗成功"),
  "Long balls completed": (ko: "롱패스 성공", ja: "ロングパス成功", zh: "长传成功"),
  "Accurate passes": (ko: "패스 성공", ja: "パス成功", zh: "成功传球"),
  "Goals conceded": (ko: "실점", ja: "失点", zh: "失球"),
  "Very Poor": (ko: "매우 낮음", ja: "非常に低い", zh: "很差"),
  "Poor": (ko: "낮음", ja: "低い", zh: "较差"),
  "Fair": (ko: "보통", ja: "標準", zh: "一般"),
  "Good": (ko: "좋음", ja: "良い", zh: "良好"),
  "Very Good": (ko: "매우 좋음", ja: "とても良い", zh: "很好"),
  "Excellent": (ko: "뛰어남", ja: "優秀", zh: "出色"),
  "crucial": (ko: "핵심 선수", ja: "中心選手", zh: "核心球员"),
  "Crucial": (ko: "핵심 선수", ja: "中心選手", zh: "核心球员"),
  "important": (ko: "주요 선수", ja: "主力選手", zh: "重要球员"),
  "Important": (ko: "주요 선수", ja: "主力選手", zh: "重要球员"),
  "rotation": (ko: "로테이션", ja: "ローテーション", zh: "轮换球员"),
  "Rotation": (ko: "로테이션", ja: "ローテーション", zh: "轮换球员"),
  "sporadic": (ko: "제한적 출전", ja: "出場機会が少ない", zh: "偶尔出场"),
  "Sporadic": (ko: "제한적 출전", ja: "出場機会が少ない", zh: "偶尔出场"),
  "prospect": (ko: "유망주", ja: "有望な若手", zh: "潜力新星"),
  "Prospect": (ko: "유망주", ja: "有望な若手", zh: "潜力新星"),
  "Build Up": (ko: "빌드업", ja: "ビルドアップ", zh: "组织进攻"),
  "Defensive Actions": (ko: "수비 행동", ja: "守備アクション", zh: "防守动作"),
  "Work Rate": (ko: "활동량", ja: "運動量", zh: "跑动积极性"),
  "Link Up": (ko: "연계", ja: "連携", zh: "串联"),
  "Available in {observed}/{total} matches": (
    ko: "{total}경기 중 {observed}경기에서 제공",
    ja: "{total}試合中{observed}試合で提供",
    zh: "{total}场比赛中有{observed}场数据"
  ),
  "{count} Followers": (
    ko: "팔로워 {count}명",
    ja: "フォロワー {count}人",
    zh: "{count}位关注者"
  ),
  "{rank} place": (ko: "{rank}위", ja: "{rank}位", zh: "第{rank}名"),
  "Rating {rating}": (ko: "평점 {rating}", ja: "評価 {rating}", zh: "评分 {rating}"),
  "{position} • {count} MP": (
    ko: "{position} • {count}경기 출전",
    ja: "{position} • {count}試合出場",
    zh: "{position} • 出场{count}次"
  ),
  "Select a player with the same season position ({position}).": (
    ko: "같은 시즌 포지션({position})의 선수를 선택해 주세요.",
    ja: "同じシーズンポジション（{position}）の選手を選んでください。",
    zh: "请选择本赛季位置相同（{position}）的球员。"
  ),
  "Top 3 stats where the player ranks best in the league. The displayed stats will only reflect good performance.":
      (
    ko: "선수가 리그에서 가장 높은 순위를 기록한 상위 3개 통계예요. 좋은 성과를 보인 통계만 표시돼요.",
    ja: "リーグ内で選手の順位が最も高い上位3つのスタッツです。好成績のスタッツのみ表示します。",
    zh: "展示该球员在联赛中排名最高的3项数据，仅显示表现出色的统计项。"
  ),
  "Current season: {season}.": (
    ko: "현재 시즌: {season}.",
    ja: "現在のシーズン：{season}。",
    zh: "当前赛季：{season}。"
  ),
  "{matches} rated appearances. {players} players across the five leagues.": (
    ko: "평점이 있는 {matches}경기 출전. 5대 리그 선수 {players}명 기준.",
    ja: "評価のある出場{matches}試合。5大リーグの{players}選手が対象。",
    zh: "有评分的{matches}次出场。参考五大联赛的{players}名球员。"
  ),
  "Compares season rating and share of playing time with expectations for the player's estimated gross wage, club wage level, league and position. The two differences carry equal weight. Fair means within the usual prediction error; higher grades mean more return for the wage. Transfer fees are not included.":
      (
    ko: "시즌 평점과 출전 시간 비중을 선수의 추정 세전 급여, 구단 급여 수준, 리그, 포지션에 따른 예상치와 비교해요. 두 차이는 같은 비중으로 반영해요. '보통'은 일반적인 예측 오차 범위 안이라는 뜻이며, 등급이 높을수록 급여 대비 성과가 좋아요. 이적료는 포함하지 않아요.",
    ja: "シーズン評価と出場時間の割合を、推定税引前給与、クラブの給与水準、リーグ、ポジションに基づく予測値と比較します。2つの差を同じ比重で反映します。「標準」は通常の予測誤差の範囲内を表し、等級が高いほど給与に対する成果が優れています。移籍金は含みません。",
    zh: "将赛季评分和出场时间占比与根据球员预估税前薪资、俱乐部薪资水平、联赛及位置得出的预期值进行比较。两项差异权重相同。“一般”表示在通常的预测误差范围内，等级越高表示薪资回报越好。不包含转会费。"
  ),
  "Recent performance over the latest 5 league appearances this season, weighted by playing time and calibrated recency. Compared with all positions across the five leagues.":
      (
    ko: "이번 시즌 최근 리그 5경기의 활약을 출전 시간과 보정된 최신성에 따라 가중해요. 5대 리그의 모든 포지션 선수와 비교해요.",
    ja: "今シーズン直近5回のリーグ出場を、出場時間と調整済みの新しさで重み付けした指標です。5大リーグの全ポジションと比較します。",
    zh: "对本赛季最近5次联赛出场表现，按出场时间和经校准的时间权重进行计算。与五大联赛所有位置的球员比较。"
  ),
  "Based on league playing time while available at this club, excluding recorded injuries and suspensions. Prospect means low usage and age 21 or younger on the date the role is calculated. A role is shown after it has been calculated from verified data.":
      (
    ko: "기록된 부상과 징계 기간을 제외하고, 이 구단에서 출전 가능했던 리그 시간 중 실제 출전 시간을 기준으로 정해요. 유망주는 계산일 기준 21세 이하이면서 출전 비중이 낮은 선수를 뜻해요. 검증된 데이터로 계산한 뒤 역할을 표시해요.",
    ja: "記録された負傷・出場停止を除き、このクラブで出場可能だったリーグ時間に占める実際の出場時間で判定します。有望な若手は、計算日時点で21歳以下かつ出場割合が低い選手です。検証済みデータで算出後に表示します。",
    zh: "根据在该俱乐部可出场的联赛时间中的实际出场占比判定，排除已记录的伤病和停赛。潜力新星指计算当天21岁及以下且出场比例较低的球员。角色根据已核实数据计算后显示。"
  ),
  "Europe": (ko: "유럽", ja: "ヨーロッパ", zh: "欧洲"),
  "Too many authentication requests": (
    ko: "로그인 요청이 많아요. 잠시 후 다시 시도해 주세요.",
    ja: "ログイン要求が多すぎます。しばらくしてからお試しください。",
    zh: "登录请求过多，请稍后重试。"
  ),
  "Invalid or expired session": (
    ko: "로그인 정보가 만료됐어요. 다시 로그인해 주세요.",
    ja: "ログインの有効期限が切れました。再度ログインしてください。",
    zh: "登录已过期，请重新登录。"
  ),
  "Email or username is already registered": (
    ko: "이미 사용 중인 이메일 또는 사용자 이름이에요.",
    ja: "このメールアドレスまたはユーザー名は登録済みです。",
    zh: "该邮箱或用户名已被注册。"
  ),
  "Invalid, expired, or exhausted verification code": (
    ko: "인증 코드가 틀렸거나 만료됐어요. 새 코드를 받아 주세요.",
    ja: "認証コードが無効または期限切れです。新しいコードを取得してください。",
    zh: "验证码无效或已过期，请获取新验证码。"
  ),
  "Invalid username or password": (
    ko: "사용자 이름이나 비밀번호를 확인해 주세요.",
    ja: "ユーザー名またはパスワードを確認してください。",
    zh: "请检查用户名或密码。"
  ),
  "No email account found. Use the social provider used at signup": (
    ko: "이메일 계정이 없어요. 가입할 때 쓴 소셜 로그인으로 계속해 주세요.",
    ja: "メールアカウントがありません。登録時のソーシャルログインをご利用ください。",
    zh: "未找到邮箱账号，请使用注册时的社交登录方式。"
  ),
  "No account found for this social identity": (
    ko: "이 소셜 계정으로 가입한 계정이 없어요.",
    ja: "このソーシャルアカウントで登録されたアカウントがありません。",
    zh: "未找到与此社交账号关联的账号。"
  ),
  "Email changes require an email password account": (
    ko: "이메일과 비밀번호로 가입한 계정만 이메일을 변경할 수 있어요.",
    ja: "メールとパスワードで登録したアカウントのみメールを変更できます。",
    zh: "仅通过邮箱和密码注册的账号可更改邮箱。"
  ),
  "Invalid current password": (
    ko: "현재 비밀번호를 확인해 주세요.",
    ja: "現在のパスワードを確認してください。",
    zh: "请检查当前密码。"
  ),
  "Use a different email address": (
    ko: "다른 이메일 주소를 입력해 주세요.",
    ja: "別のメールアドレスを入力してください。",
    zh: "请输入其他邮箱地址。"
  ),
  "Email is already registered": (
    ko: "이미 사용 중인 이메일이에요.",
    ja: "このメールアドレスは登録済みです。",
    zh: "该邮箱已被注册。"
  ),
  "Invalid, expired, exhausted, or unrelated email verification codes": (
    ko: "이메일 인증 코드를 확인하거나 새 코드를 받아 주세요.",
    ja: "メール認証コードを確認するか、新しいコードを取得してください。",
    zh: "请检查邮箱验证码或获取新验证码。"
  ),
  "{user} and {count} more users liked your post.": (
    ko: "{user}님 외 {count}명이 내 게시글을 좋아해요.",
    ja: "{user}さんと他{count}人があなたの投稿にいいねしました。",
    zh: "{user}和其他{count}位用户赞了你的帖子。"
  ),
  "{user} liked your post.": (
    ko: "{user}님이 내 게시글을 좋아해요.",
    ja: "{user}さんがあなたの投稿にいいねしました。",
    zh: "{user}赞了你的帖子。"
  ),
  "{user} commented on your post: ": (
    ko: "{user}님이 내 게시글에 댓글을 남겼어요: ",
    ja: "{user}さんがあなたの投稿にコメントしました：",
    zh: "{user}评论了你的帖子："
  ),
  "{user} liked your comment.": (
    ko: "{user}님이 내 댓글을 좋아해요.",
    ja: "{user}さんがあなたのコメントにいいねしました。",
    zh: "{user}赞了你的评论。"
  ),
  "{user} replied to your comment: ": (
    ko: "{user}님이 내 댓글에 답글을 남겼어요: ",
    ja: "{user}さんがあなたのコメントに返信しました：",
    zh: "{user}回复了你的评论："
  ),
  "Last {count} matches": (
    ko: "최근 {count}경기",
    ja: "直近{count}試合",
    zh: "最近{count}场"
  ),
  "You can follow one team per league. Following this team will replace {team}. Continue?":
      (
    ko: "리그마다 한 팀만 팔로우할 수 있어요. 이 팀을 팔로우하면 {team} 대신 추가돼요. 계속할까요?",
    ja: "各リーグでフォローできるのは1チームです。このチームを選ぶと{team}と入れ替わります。続けますか？",
    zh: "每个联赛只能关注一支球队。关注此球队将替换{team}。是否继续？"
  ),
  "Shot stopping": (ko: "선방", ja: "シュートストップ", zh: "扑救"),
  "Expected Goals": (ko: "기대 득점", ja: "期待得点", zh: "预期进球"),
  "Expected back today": (ko: "오늘 복귀할 예정이에요", ja: "今日復帰する予定です", zh: "预计今天复出"),
  "Expected back in 1 day": (
    ko: "1일 뒤 복귀할 예정이에요",
    ja: "1日後に復帰する予定です",
    zh: "预计1天后复出"
  ),
  "Expected back in {count} days": (
    ko: "{count}일 뒤 복귀할 예정이에요",
    ja: "{count}日後に復帰する予定です",
    zh: "预计{count}天后复出"
  ),
  "Expected back in 1 week": (
    ko: "1주 뒤 복귀할 예정이에요",
    ja: "1週間後に復帰する予定です",
    zh: "预计1周后复出"
  ),
  "Expected back in {count} weeks": (
    ko: "{count}주 뒤 복귀할 예정이에요",
    ja: "{count}週間後に復帰する予定です",
    zh: "预计{count}周后复出"
  ),
  "No return date yet": (
    ko: "언제 복귀할지 아직 몰라요",
    ja: "いつ復帰できるかはまだわかりません",
    zh: "暂时还不知道什么时候复出"
  ),
  "Open {name}": (ko: "{name} 보기", ja: "{name}を開く", zh: "查看{name}"),
  "Top Scorer": (ko: "득점왕", ja: "得点王", zh: "最佳射手"),
  "Top Assists": (ko: "도움왕", ja: "アシスト王", zh: "助攻王"),
  "Goalkeeper of the Year": (ko: "올해의 골키퍼", ja: "年間最優秀ゴールキーパー", zh: "年度最佳门将"),
  "Defender of the Year": (ko: "올해의 수비수", ja: "年間最優秀ディフェンダー", zh: "年度最佳后卫"),
  "Midfielder of the Year": (ko: "올해의 미드필더", ja: "年間最優秀ミッドフィルダー", zh: "年度最佳中场"),
  "Forward of the Year": (ko: "올해의 공격수", ja: "年間最優秀フォワード", zh: "年度最佳前锋"),
  "Player of the Year": (ko: "올해의 선수", ja: "年間最優秀選手", zh: "年度最佳球员"),
  "European Golden Shoe": (ko: "유러피언 골든슈", ja: "ヨーロッパ・ゴールデンシュー", zh: "欧洲金靴奖"),
  "Golden Boy": (ko: "골든보이", ja: "ゴールデンボーイ", zh: "金童奖"),
  "Ballon d'Or": (ko: "발롱도르", ja: "バロンドール", zh: "金球奖"),
  " Min.": (ko: "분", ja: "分", zh: "分钟"),
  "Explanation": (ko: "설명", ja: "説明", zh: "说明"),
  "Calculated using proprietary performance metrics and predictive analytics model":
      (
    ko: "1touch의 자체 경기력 지표와 예측 분석 모델을 사용해 계산해요.",
    ja: "独自のパフォーマンス指標と予測分析モデルを使って算出しています。",
    zh: "使用专有表现指标和预测分析模型计算。"
  ),
  "Percentage of ball recovery locations across the lower, middle, and upper thirds compared against the league average.":
      (
    ko: "수비·중앙·공격 지역별 공 회수 비율을 리그 평균과 비교해요.",
    ja: "守備・中盤・攻撃の各エリアでのボール奪回割合をリーグ平均と比較します。",
    zh: "比较防守、中场和进攻三区的夺回球权比例与联赛平均值。"
  ),
  "Shotmap showing where each shot on target was taken, with lines pointing to where it was aimed.":
      (
    ko: "유효 슈팅을 시도한 위치와 공이 향한 위치를 선으로 보여주는 슛맵이에요.",
    ja: "枠内シュートを放った位置と、狙った方向を線で示すシュートマップです。",
    zh: "射门图显示每次射正的起脚位置，并用线条指向瞄准的位置。"
  ),
  "Evaluates and ranks players using 1touch's own data-driven performance metrics.":
      (
    ko: "1touch의 자체 데이터 기반 경기력 지표로 선수를 평가하고 순위를 매겨요.",
    ja: "1touch独自のデータに基づくパフォーマンス指標で選手を評価・順位付けします。",
    zh: "使用1touch自有的数据驱动表现指标评估球员并进行排名。"
  ),
  "Highlights players with the highest performance growth over recent matches, based on 1touch metrics.":
      (
    ko: "1touch 지표를 기준으로 최근 경기에서 경기력이 가장 크게 향상된 선수를 보여줘요.",
    ja: "1touchの指標に基づき、最近の試合で最も成長した選手を紹介します。",
    zh: "根据1touch指标，展示近期比赛中表现进步最大的球员。"
  ),
  "Measured by comparing actual salary against 1touch’s predicted market value based on performance and playtime.":
      (
    ko: "실제 급여를 경기력과 출전 시간을 바탕으로 1touch가 예측한 시장 가치와 비교해요.",
    ja: "実際の給与を、パフォーマンスと出場時間から1touchが予測した市場価値と比較します。",
    zh: "将实际薪资与1touch根据表现和出场时间预测的市场价值进行比较。"
  ),
};
