"""인증 목적과 언어가 달라도 같은 문구 원본과 메일 레이아웃을 사용해요."""
from html import escape
import json
from pathlib import Path
from string import Template

from .auth_security import CODE_LIFETIME_MINUTES

TEMPLATE_DIRECTORY = Path(__file__).with_name("email_templates")
# messages.dart에서 생성한 파일을 읽어 앱과 서버의 번역 원본을 하나로 유지해요.
_COPY = json.loads((TEMPLATE_DIRECTORY / "messages.json").read_text(encoding="utf-8"))["messages"]["verification"]


def render_verification_email(code: str, purpose: str, language: str) -> tuple[str, str, str]:
    copy = _COPY[language]
    # 메일 안내와 실제 인증번호 만료 시간이 달라지지 않도록 같은 설정을 써요.
    instructions = copy[purpose].format(minutes=CODE_LIFETIME_MINUTES)
    plain = f"{copy['code_label']}\n{code}\n\n{instructions}\n\n{copy['ignore']}\n"
    values = {"language": language, "title": copy["title"], "code_label": copy["code_label"],
              "instructions": instructions, "ignore": copy["ignore"]}
    values = {key: escape(value) for key, value in values.items()}
    # 원본의 여섯 밑줄 위에 번호를 넣고, 복사할 때 공백이 섞이지 않게 이어 붙여요.
    # 밑줄 위치는 높이로 유지해요. 줄 높이는 박스 안쪽 높이에 4px을 더해 숫자가 위로 뜨는 글꼴 여백을 보정해요.
    values["code_digits"] = "".join(
        '<span class="verification-digit" style="display: inline-block; width: 27.42086px; '
        'height: 44.45774px; margin: 0 4.98562px; border-bottom: 2.49296px solid #9e9e9e; '
        'font-size: 28px; line-height: 60.50704px; font-weight: 700; text-align: center; vertical-align: top;">'
        f'{escape(digit)}</span>' for digit in code
    )
    template = Template((TEMPLATE_DIRECTORY / "verification.html").read_text(encoding="utf-8"))
    html = template.substitute(values)
    return copy["title"], plain, html
