import os

from email_validator import EmailNotValidError, validate_email


def normalize_email_address(value: str) -> str:
    environment = os.environ.get("FABLE_ENV", "development").strip().lower()
    allow_test_domains = environment in {"development", "dev", "local", "test"}
    try:
        result = validate_email(
            value.strip(),
            check_deliverability=False,
            test_environment=allow_test_domains,
        )
    except EmailNotValidError as error:
        raise ValueError("A valid email address is required.") from error
    return result.normalized.lower()
