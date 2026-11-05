from email_validator import EmailNotValidError, validate_email
from core.settings import DEVELOPMENT_ENVIRONMENTS, load_environment


def normalize_email_address(value: str) -> str:
    allow_test_domains = load_environment() in DEVELOPMENT_ENVIRONMENTS
    try:
        result = validate_email(
            value.strip(),
            check_deliverability=False,
            test_environment=allow_test_domains,
        )
    except EmailNotValidError as error:
        raise ValueError("A valid email address is required.") from error
    return result.normalized.lower()
