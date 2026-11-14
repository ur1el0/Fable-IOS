import os

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("FABLE_ENV", "test")
os.environ.setdefault("FABLE_RATE_LIMIT_ENABLED", "false")

from api.v1.endpoints import health
from main import app


client = TestClient(app)


def test_liveness_check_does_not_query_database(monkeypatch):
    def fail_if_database_is_used():
        pytest.fail("liveness check must not open a database connection")

    monkeypatch.setattr(health, "get_db", fail_if_database_is_used)

    response = client.get("/api/v1/live")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}
