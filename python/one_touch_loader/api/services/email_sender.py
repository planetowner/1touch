"""SES의 암호화된 SMTP 연결로 인증 메일을 보내요."""
import smtplib
import ssl
from email.message import EmailMessage

from fastapi import HTTPException

from .auth_security import CODE_LIFETIME_MINUTES, required_setting


def send_verification_code(email: str, code: str, purpose: str) -> None:
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
    message["Subject"] = "1Touch verification code"
    # 인증번호 발송 규칙은 공유하고, 사용자가 요청한 작업 안내만 구분해요.
    action = {
        "signup": "create your account", "password_reset": "reset your password",
        "username_recovery": "find your 1Touch username", "email_change": "change your account email address",
    }[purpose]
    message.set_content(
        f"Your 1Touch code is {code}.\n\nUse it to {action}. "
        f"It expires in {CODE_LIFETIME_MINUTES} minutes.\n"
        "If you did not request this code, you can ignore this email.\n"
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
