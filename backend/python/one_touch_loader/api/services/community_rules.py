"""모든 팀이 공유하는 이용 약속을 백엔드 코드에서 관리해요."""
from ..schemas.community import CommunityLanguage, CommunityRules


# 사용자 확정 문구예요. 언어마다 내용만 바꾸고 조회·응답 구조는 함께 써요.
# 번호·굵기·핀 아이콘은 앱에서 표시하도록 문구와 구분해요.
_RULES = {
    "ko": {
        "title": "커뮤니티 이용 약속",
        "items": [
            {"title": "의견이 달라도 서로 존중해요",
             "body": "생각이 달라도 상대방을 공격하지 말고, 의견으로 이야기해주세요."},
            {"title": "선수를 존중해요",
             "body": "플레이와 경기력에 대한 의견은 자유롭게 나눠주세요. 선수 개인을 향한 모욕이나 인신공격은 삼가 주세요."},
            {"title": "응원하는 팀이 달라도 괜찮아요",
             "body": "놀리고 티격태격하는 것도 축구의 재미예요. 팀이나 팬을 깎아내리는 말은 피해 주세요."},
            {"title": "모두가 편하게 볼 수 있는 글을 올려요",
             "body": "도배, 혐오·차별 표현, 광고성 글, 수상한 링크는 올리지 말아 주세요."},
            {"title": "좋은 분위기를 함께 만들어요",
             "body": "응원하고, 토론하고, 농담도 나눠주세요. 서로를 배려하며 좋은 분위기를 만들어주세요."},
        ],
        "confirm_label": "확인했어요",
    },
    "en": {
        "title": "Community Ground Rules",
        "items": [
            {"title": "Keep it about football",
             "body": "Disagree with the take, not the person."},
            {"title": "Respect the players",
             "body": "Talk about mistakes and performances without making it personal."},
            {"title": "Rivalries are part of the fun",
             "body": "Banter and friendly rivalry are welcome. Keep it fun and respectful."},
            {"title": "Keep the space safe",
             "body": "Avoid spam, hate or discriminatory speech, promotional posts, and suspicious links."},
            {"title": "Add to the atmosphere",
             "body": "Cheer, debate, and joke around. Be considerate and help keep the community welcoming."},
        ],
        "confirm_label": "Got it",
    },
    "ja": {
        "title": "コミュニティのルール",
        "items": [
            {"title": "意見が違っても、お互いを尊重しましょう",
             "body": "考えが違っても、相手を攻撃せず、意見そのものについて話してください。"},
            {"title": "選手を尊重しましょう",
             "body": "プレーやパフォーマンスについては自由に意見を交わしてください。選手個人への侮辱や人格攻撃は控えてください。"},
            {"title": "応援するチームが違っても大丈夫です",
             "body": "軽いからかいやライバル同士のやり取りも、サッカーの楽しみのひとつです。楽しく、相手への敬意は忘れないでください。"},
            {"title": "みんなが安心して読める投稿をしましょう",
             "body": "スパム投稿、ヘイト・差別的な表現、宣伝目的の投稿、不審なリンクは投稿しないでください。"},
            {"title": "みんなでいい雰囲気をつくりましょう",
             "body": "応援したり、議論したり、冗談を言い合ったりしながら楽しんでください。お互いに配慮し、気持ちのいいコミュニティを一緒につくってください。"},
        ],
        "confirm_label": "わかりました",
    },
    "zh-Hans": {
        "title": "社区公约",
        "items": [
            {"title": "即使意见不同，也请互相尊重",
             "body": "想法不同没关系。请围绕观点本身交流，不要攻击他人。"},
            {"title": "请尊重球员",
             "body": "可以自由讨论球员的表现和比赛发挥。请不要侮辱球员，也不要进行人身攻击。"},
            {"title": "支持不同的球队也没关系",
             "body": "互相调侃、友好较劲也是足球的乐趣之一。请保持轻松，也尊重彼此。"},
            {"title": "请发布让大家都能安心阅读的内容",
             "body": "请不要刷屏、发表仇恨或歧视性言论、发布广告内容或可疑链接。"},
            {"title": "一起营造良好的氛围",
             "body": "欢迎一起加油、讨论、开玩笑。请彼此体谅，一起营造友好的社区氛围。"},
        ],
        "confirm_label": "我知道了",
    },
}


def get_rules_content(language: CommunityLanguage) -> CommunityRules:
    return CommunityRules(language=language, **_RULES[language])
