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
    # 박스 간격은 CSS로만 넣어 인증번호를 복사할 때 공백이 섞이지 않게 해요.
    values["code_digits"] = "".join(
        '<span class="verification-digit" style="display: inline-block; width: 26.03390px; '
        f'height: 32px; margin-left: {6 if index else 0}px; border-radius: 2.71186px; '
        'background-color: #3d3d3d; color: #ffffff; font-size: 20px; line-height: 32px; '
        'font-weight: 700; text-align: center; vertical-align: top;">'
        f'{escape(digit)}</span>' for index, digit in enumerate(code)
    )
    template = Template((TEMPLATE_DIRECTORY / "verification.html").read_text(encoding="utf-8"))
    html = template.substitute(values)
    return copy["title"], plain, html
