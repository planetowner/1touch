// 화면 문구는 네 언어에서 같은 키로 관리해요.
typedef MessageTranslations = ({String ko, String ja, String zh});

const appMessages = <String, MessageTranslations>{
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
  "Username": (ko: "유저네임", ja: "ユーザー名", zh: "用户名"),
  "Password": (ko: "비밀번호", ja: "パスワード", zh: "密码"),
  "Email": (ko: "이메일", ja: "メールアドレス", zh: "邮箱"),
  "EMAIL": (ko: "이메일", ja: "メール", zh: "邮箱"),
  "First name": (ko: "이름", ja: "名", zh: "名字"),
  "Last name": (ko: "성", ja: "姓", zh: "姓氏"),
  "Enter first name": (ko: "이름을 입력해 주세요", ja: "名を入力してください", zh: "请输入名字"),
  "Enter last name": (ko: "성을 입력해 주세요", ja: "姓を入力してください", zh: "请输入姓氏"),
  "Enter username": (ko: "유저네임을 입력해 주세요", ja: "ユーザー名を入力してください", zh: "请输入用户名"),
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
  "Welcome to 1Touch!": (
    ko: "1Touch에 오신 걸 환영해요!",
    ja: "1Touchへようこそ！",
    zh: "欢迎来到1Touch！"
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
  "Team": (ko: "팀", ja: "チーム", zh: "球队"),
  "Community": (ko: "커뮤니티", ja: "コミュニティ", zh: "社区"),
  "MY TEAM": (ko: "내 팀", ja: "マイチーム", zh: "我的球队"),
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
  "POINTS": (ko: "포인트", ja: "ポイント", zh: "积分"),
  "SETTINGS": (ko: "설정", ja: "設定", zh: "设置"),
  "About": (ko: "앱 정보", ja: "アプリについて", zh: "关于"),
  "Contact": (ko: "문의", ja: "お問い合わせ", zh: "联系我们"),
  "Contact Us": (ko: "문의하기", ja: "お問い合わせ", zh: "联系我们"),
  "General": (ko: "일반", ja: "一般", zh: "通用"),
  "Legal": (ko: "법적 고지", ja: "法的情報", zh: "法律信息"),
  "Preferences": (ko: "환경 설정", ja: "環境設定", zh: "偏好设置"),
  "Personal Info": (ko: "개인 정보", ja: "個人情報", zh: "个人信息"),
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
  "UPDATE PREFERENCES": (ko: "설정 저장", ja: "設定を保存", zh: "保存设置"),
  "UPDATE NOTIFICATIONS": (ko: "알림 설정 저장", ja: "通知設定を保存", zh: "保存通知设置"),
  "Dark Theme": (ko: "다크 모드", ja: "ダークモード", zh: "深色模式"),
  "Use dark theme": (ko: "다크 모드 사용", ja: "ダークモードにする", zh: "使用深色模式"),
  "Use light theme": (ko: "라이트 모드 사용", ja: "ライトモードにする", zh: "使用浅色模式"),
  "SOCIAL ACCOUNTS": (ko: "소셜 계정", ja: "ソーシャルアカウント", zh: "社交账号"),
  "Connected": (ko: "연결됨", ja: "連携済み", zh: "已关联"),
  "Not Connected": (ko: "연결 안 됨", ja: "未連携", zh: "未关联"),
  "DELETE ACCOUNT": (ko: "계정 삭제", ja: "アカウントを削除", zh: "删除账号"),
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
  "Retry": (ko: "다시 시도", ja: "再試行", zh: "重试"),
  "RETRY": (ko: "다시 시도", ja: "再試行", zh: "重试"),
  "Cancel": (ko: "취소", ja: "キャンセル", zh: "取消"),
  "CANCEL": (ko: "취소", ja: "キャンセル", zh: "取消"),
  "Back": (ko: "뒤로", ja: "戻る", zh: "返回"),
  "DONE": (ko: "완료", ja: "完了", zh: "完成"),
  "UPDATE": (ko: "저장", ja: "保存", zh: "保存"),
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
    ko: "로그인 세션이 만료됐어요. 다시 로그인해 주세요.",
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
  "FAVORITE TEAM": (ko: "가장 좋아하는 팀", ja: "お気に入りのチーム", zh: "最喜欢的球队"),
  "FAVORITE PLAYERS": (ko: "좋아하는 선수", ja: "お気に入りの選手", zh: "喜欢的球员"),
  "Following": (ko: "팔로잉", ja: "フォロー中", zh: "已关注"),
  "Followers": (ko: "팔로워", ja: "フォロワー", zh: "粉丝"),
  "Follow player": (ko: "선수 팔로우", ja: "選手をフォロー", zh: "关注球员"),
  "Unfollow player": (ko: "선수 팔로우 취소", ja: "選手のフォローを解除", zh: "取消关注球员"),
  "Follow team": (ko: "팀 팔로우", ja: "チームをフォロー", zh: "关注球队"),
  "Unfollow team": (ko: "팀 팔로우 취소", ja: "チームのフォローを解除", zh: "取消关注球队"),
  "Edit favorites": (ko: "즐겨찾기 수정", ja: "お気に入りを編集", zh: "编辑收藏"),
  "Add favorite players": (ko: "좋아하는 선수 추가", ja: "お気に入りの選手を追加", zh: "添加喜欢的球员"),
  "Remove player": (ko: "선수 삭제", ja: "選手を削除", zh: "移除球员"),
  "Search players to add!": (
    ko: "추가할 선수를 검색해 주세요!",
    ja: "追加する選手を検索しましょう！",
    zh: "搜索要添加的球员！"
  ),
  "Search teams to add!": (
    ko: "추가할 팀을 검색해 주세요!",
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
  "Squad": (ko: "선수단", ja: "選手一覧", zh: "阵容"),
  "Standing": (ko: "순위표", ja: "順位表", zh: "积分榜"),
  "STANDING": (ko: "순위표", ja: "順位表", zh: "积分榜"),
  "Analysis": (ko: "분석", ja: "分析", zh: "分析"),
  "ANALYSIS": (ko: "분석", ja: "分析", zh: "分析"),
  "News": (ko: "뉴스", ja: "ニュース", zh: "新闻"),
  "NEWS": (ko: "뉴스", ja: "ニュース", zh: "新闻"),
  "News & Insights": (ko: "뉴스와 인사이트", ja: "ニュースとインサイト", zh: "新闻与洞察"),
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
  "• LIVE": (ko: "• 라이브", ja: "• ライブ", zh: "• 直播"),
  "FIXTURE": (ko: "경기 일정", ja: "試合日程", zh: "赛程"),
  "CALENDAR": (ko: "캘린더", ja: "カレンダー", zh: "日历"),
  "RECENT MATCHES": (ko: "최근 경기", ja: "最近の試合", zh: "近期比赛"),
  "PAST MATCHES": (ko: "지난 경기", ja: "過去の試合", zh: "过往比赛"),
  "PAST": (ko: "지난 경기", ja: "過去の試合", zh: "已结束"),
  "UPCOMING": (ko: "예정 경기", ja: "今後の試合", zh: "即将开始"),
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
  "Club": (ko: "클럽", ja: "クラブ", zh: "俱乐部"),
  "MP": (ko: "경기", ja: "試合", zh: "场次"),
  "W": (ko: "승", ja: "勝", zh: "胜"),
  "D": (ko: "무", ja: "分", zh: "平"),
  "L": (ko: "패", ja: "敗", zh: "负"),
  "GF": (ko: "득점", ja: "得点", zh: "进球"),
  "GA": (ko: "실점", ja: "失点", zh: "失球"),
  "GD": (ko: "득실차", ja: "得失点差", zh: "净胜球"),
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
  "BEST ELEVEN": (ko: "베스트 일레븐", ja: "ベストイレブン", zh: "最佳十一人"),
  "BEST XI": (ko: "베스트 일레븐", ja: "ベストイレブン", zh: "最佳十一人"),
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
  "Defense": (ko: "수비", ja: "守備", zh: "防守"),
  "Defending": (ko: "수비", ja: "守備", zh: "防守"),
  "POSSESSION": (ko: "점유", ja: "ポゼッション", zh: "控球"),
  "Possession": (ko: "점유", ja: "ポゼッション", zh: "控球"),
  "PROGRESSION": (ko: "전진", ja: "前進", zh: "推进"),
  "Progression": (ko: "전진", ja: "前進", zh: "推进"),
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
    ko: "리그\n우승 확률",
    ja: "リーグ\n優勝確率",
    zh: "联赛\n夺冠概率"
  ),
  "Chances to finish\nTOP 4": (
    ko: "4위 이내\n진입 확률",
    ja: "4位以内の\n確率",
    zh: "进入前四的\n概率"
  ),
  "Chances to finish\nTOP 6": (
    ko: "6위 이내\n진입 확률",
    ja: "6位以内の\n確率",
    zh: "进入前六的\n概率"
  ),
  "Chances of\nDIRECT RELEGATION": (
    ko: "직접\n강등 확률",
    ja: "自動降格の\n確率",
    zh: "直接降级的\n概率"
  ),
  "Chances of\nRELEGATION PLAYOFF": (
    ko: "강등 플레이오프\n진출 확률",
    ja: "降格プレーオフの\n確率",
    zh: "参加保级附加赛的\n概率"
  ),
  "INJURY STATUS": (ko: "부상 현황", ja: "負傷状況", zh: "伤病情况"),
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
  "LOAN": (ko: "임대", ja: "期限付き移籍", zh: "租借"),
  "Loan": (ko: "임대", ja: "期限付き移籍", zh: "租借"),
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
  "Competition statistics for the selected season.": (
    ko: "선택한 시즌의 대회 기록이에요.",
    ja: "選択したシーズンの大会成績です。",
    zh: "所选赛季的赛事数据。"
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
  "CURRENT": (ko: "현재", ja: "現在", zh: "当前"),
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
  "1Touch Ranking": (ko: "1Touch 순위", ja: "1Touchランキング", zh: "1Touch排名"),
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
  "Dominance": (ko: "지배력", ja: "支配力", zh: "统治力"),
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
  "AGAINST": (ko: "상대", ja: "対戦相手", zh: "对手"),
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
  "You can attach up to 10 files.": (
    ko: "파일은 최대 10개까지 첨부할 수 있어요.",
    ja: "ファイルは10個まで添付できます。",
    zh: "最多可添加10个文件。"
  ),
  "Popular": (ko: "인기순", ja: "人気順", zh: "热门"),
  "Newest": (ko: "최신순", ja: "新しい順", zh: "最新"),
  "Latest": (ko: "최신", ja: "最新", zh: "最新"),
  "Best": (ko: "인기", ja: "人気", zh: "热门"),
  "No comments yet.": (ko: "아직 댓글이 없어요.", ja: "コメントはまだありません。", zh: "暂无评论。"),
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
  "Unable to update like. Please try again.": (
    ko: "좋아요를 변경하지 못했어요. 다시 시도해 주세요.",
    ja: "いいねを更新できませんでした。もう一度お試しください。",
    zh: "无法更新点赞，请重试。"
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
    ko: "신고 내용을 확인할게요. 보내주신 신고는 모두가 안전하게 1Touch를 이용하는 데 도움이 돼요.",
    ja: "ご報告を確認します。皆さまのご協力が、安心して1Touchを利用できる環境づくりにつながります。",
    zh: "我们会核查举报内容。你的每一次举报都能帮助大家更安全地使用1Touch。"
  ),
  "Unable to submit report. Please try again.": (
    ko: "신고를 보내지 못했어요. 다시 시도해 주세요.",
    ja: "報告を送信できませんでした。もう一度お試しください。",
    zh: "无法提交举报，请重试。"
  ),
  "Community Ground Rules": (ko: "커뮤니티 이용 규칙", ja: "コミュニティルール", zh: "社区规则"),
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
  "Reactions": (ko: "반응", ja: "リアクション", zh: "互动"),
  "Match Reminder": (ko: "경기 알림", ja: "試合リマインダー", zh: "比赛提醒"),
  "Kickoff, Half Time, Full Time": (
    ko: "킥오프, 전반 종료, 경기 종료",
    ja: "キックオフ・前半終了・試合終了",
    zh: "开球、半场、全场"
  ),
  "New bets": (ko: "새 베팅", ja: "新しい予想", zh: "新竞猜"),
  "New Bet Available": (ko: "새 베팅이 열렸어요", ja: "新しい予想が可能です", zh: "新的竞猜已开放"),
  "Post-match results": (ko: "경기 결과", ja: "試合結果", zh: "赛后结果"),
  "Post-match Result": (ko: "경기 결과", ja: "試合結果", zh: "赛后结果"),
  "APPLY TO ALL PLAYERS": (ko: "모든 선수에 적용", ja: "すべての選手に適用", zh: "应用到所有球员"),
  "APPLY TO ALL TEAMS": (ko: "모든 팀에 적용", ja: "すべてのチームに適用", zh: "应用到所有球队"),
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
  "Not enough points.": (ko: "포인트가 부족해요.", ja: "ポイントが足りません。", zh: "积分不足。"),
  "You need at least 10 pts to place a bet.": (
    ko: "베팅하려면 최소 10포인트가 필요해요.",
    ja: "予想には最低10ポイントが必要です。",
    zh: "参与竞猜至少需要10积分。"
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
    ko: "요청이 너무 많아요. 잠시 후 다시 시도해 주세요.",
    ja: "リクエストが多すぎます。しばらくしてからお試しください。",
    zh: "请求过多，请稍后重试。"
  ),
  "The server is taking too long to respond. Please try again.": (
    ko: "서버 응답이 지연되고 있어요. 다시 시도해 주세요.",
    ja: "サーバーの応答が遅れています。もう一度お試しください。",
    zh: "服务器响应超时，请重试。"
  ),
  "There is a server problem. Please try again later.": (
    ko: "서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.",
    ja: "サーバーに問題が発生しました。しばらくしてからお試しください。",
    zh: "服务器出现问题，请稍后重试。"
  ),
  "The service is currently unavailable. Please try again later.": (
    ko: "현재 서비스를 이용할 수 없어요. 잠시 후 다시 시도해 주세요.",
    ja: "現在サービスを利用できません。しばらくしてからお試しください。",
    zh: "服务暂不可用，请稍后重试。"
  ),
  "Servers could not connect. Please try again later.": (
    ko: "서버 간 연결에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.",
    ja: "サーバー間の接続に問題があります。しばらくしてからお試しください。",
    zh: "服务器间连接出现问题，请稍后重试。"
  ),
  "Go home": (ko: "홈으로", ja: "ホームへ", zh: "返回首页"),
  "Sign in again": (ko: "다시 로그인", ja: "再ログイン", zh: "重新登录"),
  "Please join again": (ko: "다시 입장해 주세요", ja: "もう一度参加してください", zh: "请重新加入"),
  "Pass incomplete": (ko: "패스 연결에 실패했어요", ja: "パスがつながりませんでした", zh: "传球未成功"),
  "Beyond added time": (ko: "추가시간을 넘겼어요", ja: "追加時間を過ぎました", zh: "已超出补时时间"),
  "Offside!": (ko: "오프사이드!", ja: "オフサイド！", zh: "越位！"),
  "Red card!": (ko: "레드카드!", ja: "レッドカード！", zh: "红牌！"),
  "Match interrupted": (ko: "잠시 경기 중단", ja: "試合が一時中断しています", zh: "比赛暂时中断"),
  "VAR check": (ko: "VAR 확인 중", ja: "VAR確認中", zh: "VAR检查中"),
  "Coming soon": (ko: "아직 준비 중이에요", ja: "準備中です", zh: "敬请期待"),
  "SWITCH": (ko: "변경", ja: "切り替え", zh: "切换"),
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
  "By clicking sign up, I hereby agree and consent to\n1Touch’s Terms & Conditions; I confirm that I have\nread 1Touch’s Privacy Policy.":
      (
    ko: "회원가입을 누르면 1Touch 이용약관에 동의하고\n개인정보 처리방침을 확인한 것으로 간주해요.",
    ja: "新規登録を押すと、1Touchの利用規約に同意し、\nプライバシーポリシーを確認したものとみなします。",
    zh: "点击注册即表示同意1Touch服务条款，\n并确认已阅读隐私政策。"
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
  "{count} participants · Home / Draw / Away": (
    ko: "{count}명 참여 · 홈 / 무승부 / 원정",
    ja: "{count}人参加 · ホーム / 引き分け / アウェイ",
    zh: "{count}人参与 · 主胜 / 平局 / 客胜"
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
  "{season} {competition} · {position} · reference players with at least {minutes} minutes.":
      (
    ko: "{season} {competition} · {position} · {minutes}분 이상 출전한 선수 기준",
    ja: "{season} {competition} · {position} · {minutes}分以上出場した選手が対象",
    zh: "{season} {competition} · {position} · 参考出场至少{minutes}分钟的球员"
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
  "Full time 3-1 — Big win for Barcelona!": (
    ko: "경기 종료 3–1 — 바르셀로나의 승리!",
    ja: "試合終了3–1 — バルセロナが快勝！",
    zh: "全场结束3–1，巴塞罗那大胜！"
  ),
  "Kang-In is in the XI 👕": (
    ko: "이강인이 선발로 출전해요 👕",
    ja: "イ・ガンインが先発出場 👕",
    zh: "李刚仁首发出场 👕"
  ),
  "Kane scored twice! Bayern 2-0 Dortmund.": (
    ko: "케인 멀티골! 바이에른 2–0 도르트문트.",
    ja: "ケインが2得点！バイエルン2–0ドルトムント。",
    zh: "凯恩梅开二度！拜仁2–0多特蒙德。"
  ),
  "Barcelona vs Real Madrid — place your prediction.": (
    ko: "바르셀로나 vs 레알 마드리드 — 승부를 예측해 보세요.",
    ja: "バルセロナ対レアル・マドリード — 勝敗を予想しましょう。",
    zh: "巴塞罗那对阵皇家马德里，快来预测赛果。"
  ),
  "Lewandowski scored! Barcelona lead 1-0.": (
    ko: "레반도프스키 득점! 바르셀로나가 1–0으로 앞서요.",
    ja: "レヴァンドフスキが得点！バルセロナが1–0でリード。",
    zh: "莱万多夫斯基进球！巴塞罗那1–0领先。"
  ),
  "Your prediction was correct — Bayern won 3-1.": (
    ko: "예측에 성공했어요. 바이에른이 3–1로 이겼어요.",
    ja: "予想的中！バイエルンが3–1で勝利しました。",
    zh: "预测正确！拜仁3–1获胜。"
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
  "Since {date}": (ko: "{date}부터", ja: "{date}から", zh: "自{date}起"),
  "Through {date}": (ko: "{date}까지", ja: "{date}まで", zh: "截至{date}"),
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
};
