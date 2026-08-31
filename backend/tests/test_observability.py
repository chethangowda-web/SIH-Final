"""
Automated Test Suite for Phase 6: Operational Observability.
Validates:
1. Request/Correlation ID propagation in request/response headers.
2. Liveness, Readiness, and Operational Status probes.
3. Database connectivity and integrity validation in readiness probe.
4. Absence of sensitive configuration/secrets in health and status endpoints.
5. Structured logging sanitization and correlation ID injection.
"""
import io
import json
import logging
import sqlite3
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from app.core.logging_config import (
    get_correlation_id,
    set_correlation_id,
    sanitize_value,
    CorrelationIdFilter,
    StructuredJsonFormatter,
    TextStructuredFormatter,
    get_logger,
)


@pytest.fixture
def client():
    return TestClient(app)


def test_correlation_id_generated_automatically(client):
    """Verify that every incoming request receives an auto-generated correlation ID header."""
    response = client.get("/api/health/live")
    assert response.status_code == 200
    assert "X-Correlation-ID" in response.headers
    assert "X-Request-ID" in response.headers
    assert "X-Response-Time-Ms" in response.headers
    assert response.headers["X-Correlation-ID"].startswith("req-")
    assert response.headers["X-Correlation-ID"] == response.headers["X-Request-ID"]


def test_correlation_id_propagated_from_inbound_header(client):
    """Verify that client-provided correlation/request ID is preserved and propagated."""
    custom_cid = "client-trace-id-abc12345"
    response = client.get(
        "/api/health/live",
        headers={"X-Correlation-ID": custom_cid}
    )
    assert response.status_code == 200
    assert response.headers["X-Correlation-ID"] == custom_cid
    assert response.headers["X-Request-ID"] == custom_cid


def test_request_id_propagated_when_correlation_id_absent(client):
    """Verify fallback to X-Request-ID if X-Correlation-ID is not explicitly provided."""
    custom_req_id = "req-custom-987654"
    response = client.get(
        "/api/health/live",
        headers={"X-Request-ID": custom_req_id}
    )
    assert response.status_code == 200
    assert response.headers["X-Correlation-ID"] == custom_req_id
    assert response.headers["X-Request-ID"] == custom_req_id


def test_liveness_probe_canonical_and_alias(client):
    """Verify lightweight liveness probe at canonical /api/health/live and root alias /health/live."""
    for path in ["/api/health/live", "/health/live"]:
        response = client.get(path)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "live"
        assert data["service"] == settings.PROJECT_NAME
        assert data["version"] == settings.VERSION
        assert "timestamp" in data


def test_readiness_probe_success(client):
    """Verify readiness probe verifies database connection, table count, and integrity check."""
    for path in ["/api/health/ready", "/health/ready"]:
        response = client.get(path)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"
        assert data["database"] == "connected"
        assert data["integrity"] == "ok"
        assert data["tables_count"] > 10
        assert "timestamp" in data


def test_readiness_probe_handles_db_failure():
    """Verify readiness probe returns HTTP 503 when the database is unavailable."""
    from app.api.health import get_readiness

    # Create a closed mock connection to simulate database failure
    closed_conn = sqlite3.connect(":memory:")
    closed_conn.close()

    res = get_readiness(db=closed_conn)
    assert res.status_code == 503
    body = json.loads(res.body.decode())
    assert body["status"] == "unready"
    assert "error" in body["database"]


def test_operational_status_endpoint(client):
    """Verify comprehensive operational status telemetry."""
    for path in ["/api/health/status", "/health/status", "/api/admin/operations/status", "/admin/operations/status"]:
        response = client.get(path)
        assert response.status_code == 200
        data = response.json()
        assert data["service"] == settings.PROJECT_NAME
        assert data["active_cycle"] == "2026-09"
        assert "workflow_state" in data
        assert isinstance(data["allowed_next_states"], list)
        assert isinstance(data["blocked_conditions"], list)
        assert data["choice_window_status"] in ["OPEN", "CLOSED"]
        assert data["database_integrity"] == "ok"
        assert data["uptime_seconds"] >= 0.0


def test_health_endpoints_do_not_expose_secrets(client):
    """Verify that no sensitive configuration (e.g. SECRET_KEY, DB credentials) is leaked."""
    for path in ["/api/health", "/health", "/api/health/live", "/health/live", "/api/health/ready", "/health/ready", "/api/health/status", "/health/status"]:
        response = client.get(path)
        raw_body = response.text
        # Ensure secret key is never serialized in responses
        assert settings.SECRET_KEY not in raw_body
        assert "password" not in raw_body.lower()
        assert "secret_key" not in raw_body.lower()


def test_sensitive_value_sanitizer():
    """Verify that sensitive dictionary fields are redacted."""
    sensitive_dict = {
        "username": "admin_user",
        "password": "SuperSecretPassword123!",
        "access_token": "jwt-token-abcdef",
        "secret_key": "private-key-data",
        "nested": {
            "token": "nested-token",
            "safe_key": "safe_value"
        }
    }
    sanitized = sanitize_value("payload", sensitive_dict)
    assert sanitized["username"] == "admin_user"
    assert sanitized["password"] == "[REDACTED]"
    assert sanitized["access_token"] == "[REDACTED]"
    assert sanitized["secret_key"] == "[REDACTED]"
    assert sanitized["nested"]["token"] == "[REDACTED]"
    assert sanitized["nested"]["safe_key"] == "safe_value"


def test_structured_json_logger_formatting():
    """Verify StructuredJsonFormatter outputs valid JSON with correlation_id and timestamp."""
    formatter = StructuredJsonFormatter()
    logger = logging.getLogger("test_structured_logger")
    logger.setLevel(logging.INFO)

    set_correlation_id("test-cid-999")
    log_record = logger.makeRecord(
        name="test_logger",
        level=logging.INFO,
        fn="test_file.py",
        lno=42,
        msg="Test operational event occurred",
        args=(),
        exc_info=None,
        extra={"context": {"cycle_id": "2026-09", "password": "sensitive_val"}}
    )

    filter_obj = CorrelationIdFilter()
    filter_obj.filter(log_record)

    output = formatter.format(log_record)
    parsed = json.loads(output)

    assert parsed["level"] == "INFO"
    assert parsed["logger"] == "test_logger"
    assert parsed["correlation_id"] == "test-cid-999"
    assert parsed["message"] == "Test operational event occurred"
    assert parsed["context"]["cycle_id"] == "2026-09"
    assert parsed["context"]["password"] == "[REDACTED]"


def test_text_structured_logger_formatting():
    """Verify TextStructuredFormatter produces clean human-readable log line."""
    formatter = TextStructuredFormatter()
    logger = logging.getLogger("test_text_logger")

    set_correlation_id("cid-console-123")
    log_record = logger.makeRecord(
        name="test_text",
        level=logging.WARNING,
        fn="test_file.py",
        lno=10,
        msg="Sample warning message",
        args=(),
        exc_info=None
    )

    filter_obj = CorrelationIdFilter()
    filter_obj.filter(log_record)

    output = formatter.format(log_record)
    assert "[WARNING]" in output or "[WARNING" in output
    assert "[cid-console-123]" in output
    assert "Sample warning message" in output
