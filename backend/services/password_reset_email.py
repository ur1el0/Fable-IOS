from __future__ import annotations

from dataclasses import dataclass
from email.message import EmailMessage
import logging
import os
import smtplib
import ssl
from typing import Optional

from core.email_validation import normalize_email_address
from services.auth_service import discard_password_reset_token


logger = logging.getLogger(__name__)


class EmailDeliveryConfigurationError(RuntimeError):
    pass


@dataclass(frozen=True)
class SMTPSettings:
    host: str
    port: int
    username: Optional[str]
    password: Optional[str]
    from_address: str


def load_smtp_settings() -> SMTPSettings:
    host = os.environ.get("FABLE_SMTP_HOST", "").strip()
    raw_port = os.environ.get("FABLE_SMTP_PORT", "587").strip()
    username = os.environ.get("FABLE_SMTP_USERNAME", "").strip() or None
    password = os.environ.get("FABLE_SMTP_PASSWORD", "") or None
    from_address = os.environ.get("FABLE_SMTP_FROM_EMAIL", "").strip()

    try:
        port = int(raw_port)
        if not 1 <= port <= 65_535:
            raise ValueError
    except ValueError as error:
        raise EmailDeliveryConfigurationError("Password recovery email is not configured.") from error

    if not host or not from_address or (username is None) != (password is None):
        raise EmailDeliveryConfigurationError("Password recovery email is not configured.")

    try:
        normalized_from = normalize_email_address(from_address)
    except ValueError as error:
        raise EmailDeliveryConfigurationError("Password recovery email is not configured.") from error

    return SMTPSettings(host, port, username, password, normalized_from)


def send_password_reset_email(settings: SMTPSettings, recipient: str, token: str) -> None:
    message = EmailMessage()
    message["From"] = settings.from_address
    message["To"] = recipient
    message["Subject"] = "Reset your Fable password"
    message.set_content(
        "A password reset was requested for this Fable account.\n\n"
        "Enter this one-time code in the Fable app to choose a new password:\n"
        f"{token}\n\n"
        "The code expires in 15 minutes. If you did not request this, ignore this email."
    )

    tls_context = ssl.create_default_context()
    if settings.port == 465:
        server_context = smtplib.SMTP_SSL(
            settings.host,
            settings.port,
            timeout=10,
            context=tls_context,
        )
    else:
        server_context = smtplib.SMTP(settings.host, settings.port, timeout=10)

    with server_context as server:
        if settings.port != 465:
            server.ehlo()
            server.starttls(context=tls_context)
            server.ehlo()
        if settings.username is not None and settings.password is not None:
            server.login(settings.username, settings.password)
        server.send_message(message)


def deliver_password_reset_email(settings: SMTPSettings, recipient: str, token: str) -> None:
    try:
        send_password_reset_email(settings, recipient, token)
    except Exception:
        try:
            discard_password_reset_token(token)
        except Exception:
            logger.error("Failed to invalidate an undelivered password recovery code.")
        logger.warning("Password recovery email delivery failed.")
