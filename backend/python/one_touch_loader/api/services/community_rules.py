"""번역은 앱의 messages.dart에서 관리하고 공통 규칙의 메시지 키만 내려줘요."""
from ..schemas.community import CommunityRules


_RULES = {
    'title': 'Community Ground Rules',
    'items': [
        {
            'title': 'Keep it about football',
            'body': 'Disagree with the take, not the person.',
        },
        {
            'title': 'Respect the players',
            'body': 'Talk about mistakes and performances without making it personal.',
        },
        {
            'title': 'Rivalries are part of the fun',
            'body': 'Banter and friendly rivalry are welcome. Keep it fun and respectful.',
        },
        {
            'title': 'Keep the space safe',
            'body': 'Avoid spam, hate or discriminatory speech, promotional posts, and suspicious links.',
        },
        {
            'title': 'Add to the atmosphere',
            'body': 'Cheer, debate, and joke around. Be considerate and help keep the community welcoming.',
        },
    ],
}


def get_rules_content() -> CommunityRules:
    return CommunityRules(**_RULES)
