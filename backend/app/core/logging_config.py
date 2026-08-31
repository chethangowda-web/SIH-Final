"""
Structured Application Logging & Correlation ID Management for PDS DemandSync.
Provides lightweight production-grade observability without heavy external dependencies.
"""
import os
import sys
import time
import json
import logging
import uuid
import contextvars
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Callable
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# ContextVar holding the active request correlation ID across async coroutines
correlation_id_ctx: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar("correlation_id", default=None)

# Sensitive keys that must be scrubbed / redacted from all logs
SENSITIVE_KEYS = {
    "password", "secret", "token", "access_token", "api_key", "secret_key",
    "authorization", "password_hash", "salt", "signature", "aadhaar", "otp"
}


def get_correlation_id() -> Optional[str]:
    """Retrieve the current correlation ID from the active async context."""
    return correlation_id_ctx.get()


def set_correlation_id(corr_id: str) -> None:
    """Set the correlation ID in the active async context."""
    correlation_id_ctx.set(corr_id)


def sanitize_value(key: str, val: Any) -> Any:
    """Mask sensitive string or dictionary values."""
    if any(k in key.lower() for k in SENSITIVE_KEYS):
        return "[REDACTED]"
    if isinstance(val, dict):
        return {k: sanitize_value(k, v) for k, v in val.items()}
    if isinstance(val, list):
        return [sanitize_value(key, item) for item in val]
    return val


class CorrelationIdFilter(logging.Filter):
    """Logging filter that injects active correlation_id into all LogRecords."""

    def filter(self, record: logging.LogRecord) -> bool:
        corr_id = get_correlation_id()
        record.correlation_id = corr_id or "system"
        return True


class StructuredJsonFormatter(logging.Formatter):
    """
    JSON log formatter for production and structured log aggregators.
    Formats logs with ISO timestamp, level, logger name, correlation_id, and message.
    """

    def format(self, record: logging.LogRecord) -> str:
        log_entry: Dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "correlation_id": getattr(record, "correlation_id", "system"),
            "message": record.getMessage(),
        }

        # Include exception traceback if present
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)

        # Include custom extra attributes
        if hasattr(record, "context") and isinstance(record.context, dict):
            log_entry["context"] = {k: sanitize_value(k, v) for k, v in record.context.items()}

        return json.dumps(log_entry, default=str)


class TextStructuredFormatter(logging.Formatter):
    """
    Human-readable structured formatter for console development.
    Format: [TIMESTAMP] [LEVEL] [CORRELATION_ID] [LOGGER] MESSAGE
    """

    def format(self, record: logging.LogRecord) -> str:
        corr_id = getattr(record, "correlation_id", "system")
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        msg = record.getMessage()
        res = f"[{ts}] [{record.levelname:<7}] [{corr_id}] [{record.name}] {msg}"
        if record.exc_info:
            res += "\n" + self.formatException(record.exc_info)
        return res


def setup_logging(log_level: str = "INFO", use_json: Optional[bool] = None) -> logging.Logger:
    """
    Configure root application logging with CorrelationIdFilter and appropriate Formatter.
    """
    root_logger = logging.getLogger("pds_demandsync")
    root_logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

    # Remove existing handlers to avoid duplicate log entries
    root_logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    handler.addFilter(CorrelationIdFilter())

    is_json = use_json if use_json is not None else (os.getenv("LOG_FORMAT", "").lower() == "json")
    if is_json:
        handler.setFormatter(StructuredJsonFormatter())
    else:
        handler.setFormatter(TextStructuredFormatter())

    root_logger.addHandler(handler)
    root_logger.propagate = False
    return root_logger


def get_logger(name: str) -> logging.Logger:
    """Retrieve a child logger under the pds_demandsync namespace."""
    if not name.startswith("pds_demandsync"):
        return logging.getLogger(f"pds_demandsync.{name}")
    return logging.getLogger(name)


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """
    FastAPI / Starlette Middleware that extracts or creates a request correlation ID,
    stores it in contextvars, measures request latency, and adds X-Correlation-ID headers.
    """

    def __init__(self, app, header_name: str = "X-Correlation-ID"):
        super().__init__(app)
        self.header_name = header_name
        self.logger = get_logger("http")

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Extract existing correlation / request ID or generate a new unique token
        corr_id = (
            request.headers.get("x-correlation-id")
            or request.headers.get("x-request-id")
            or f"req-{uuid.uuid4().hex[:12]}"
        )
        set_correlation_id(corr_id)

        start_time = time.perf_counter()
        client_ip = request.client.host if request.client else "unknown"

        try:
            response: Response = await call_next(request)
            duration_ms = (time.perf_counter() - start_time) * 1000.0

            # Attach correlation ID headers to outgoing HTTP response
            response.headers["X-Correlation-ID"] = corr_id
            response.headers["X-Request-ID"] = corr_id
            response.headers["X-Response-Time-Ms"] = f"{duration_ms:.2f}"

            # Only log detailed requests for non-static routes
            path = request.url.path
            if not path.startswith("/app") and not path.endswith(".ico") and not path.endswith(".js"):
                self.logger.info(
                    "%s %s -> %d (%.2f ms) [ip=%s]",
                    request.method,
                    path,
                    response.statusCode if hasattr(response, "statusCode") else response.status_code,
                    duration_ms,
                    client_ip,
                )

            return response
        except Exception as exc:
            duration_ms = (time.perf_counter() - start_time) * 1000.0
            self.logger.error(
                "Unhandled error processing %s %s (%.2f ms): %s",
                request.method,
                request.url.path,
                duration_ms,
                exc,
                exc_info=True,
            )
            raise
