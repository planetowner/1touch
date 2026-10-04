"""SES의 암호화된 SMTP 연결로 인증 메일을 보내요."""
import smtplib
import ssl
from email.message import EmailMessage

from fastapi import HTTPException

from .auth_security import required_setting
from .verification_email import TEMPLATE_DIRECTORY, render_verification_email


def send_verification_code(email: str, code: str, purpose: str, language: str = "en") -> None:
    host = required_setting("SES_SMTP_HOST")
    username = required_setting("SES_SMTP_USERNAME")
    password = required_setting("SES_SMTP_PASSWORD")
    sender = required_setting("SES_FROM_EMAIL")
    feedback = required_setting("SES_FEEDBACK_EMAIL")
    message = EmailMessage()
    message["From"] = sender
    message["To"] = email
    # SES는 SMTP DATA의 Return-Path로 반송·신고를 전달해요. 수신 메일함이 없는 발신 주소와 구분해요.
    # https://docs.aws.amazon.com/ses/latest/dg/monitor-sending-activity-using-notifications-email.html
    message["Return-Path"] = feedback
    subject, plain, html = render_verification_email(code, purpose, language)
    message["Subject"] = subject
    # HTML과 일반 텍스트에 같은 문구·인증번호를 넣어요.
    message.set_content(plain)
    message.add_alternative(html, subtype="html")
    # 임시 Figma URL에 의존하지 않도록 디자인 이미지를 메일 본문에 함께 첨부해요.
    html_part = message.get_payload()[-1]
    for name in ("logo", "google-play", "app-store"):
        html_part.add_related(
            (TEMPLATE_DIRECTORY / f"{name}.png").read_bytes(), maintype="image", subtype="png",
            cid=f"<verification-{name}>", disposition="inline",
        )
    # Vultr의 외부 25번 포트 차단을 피하고 SES가 요구하는 TLS를 사용해요.
    # 전송 실패는 성공으로 표시하거나 로그에 인증번호를 대신 출력하지 않아요.
    try:
        with smtplib.SMTP(host, 587, timeout=15) as client:
            client.ehlo()
            client.starttls(context=ssl.create_default_context())
            client.ehlo()
            client.login(username, password)
            client.send_message(message)
    except (smtplib.SMTPException, OSError) as exc:
        raise HTTPException(502, "Verification email could not be sent") from exc
