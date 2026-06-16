"""Smoke tests that exercise the app without external services.

The TestClient is used outside a `with` block on purpose: that skips the
FastAPI lifespan (which would try to reach Postgres/Redis), so these run in
CI with nothing but a SQLite URL set via DATABASE_URL.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz_returns_ok():
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_create_name_rejects_blank():
    # Validation happens before any DB access, so this is a safe unit check.
    resp = client.post("/names", json={"name": ""})
    assert resp.status_code == 422
