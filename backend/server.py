"""
Production Application Server Entrypoint for PDS DemandSync.
Executes pre-flight configuration validation and launches Uvicorn server.
"""
import sys
import uvicorn
from app.core.config import settings
from app.core.logging_config import setup_logging, get_logger

def main():
    """Start PDS DemandSync application server with explicit configuration."""
    # 1. Initialize application logging
    logger = setup_logging(log_level=settings.LOG_LEVEL, use_json=(settings.LOG_FORMAT.lower() == "json"))
    logger.info("Starting PDS DemandSync Server...")
    logger.info("  Environment   : %s", settings.ENVIRONMENT)
    logger.info("  Version       : %s", settings.VERSION)
    logger.info("  Database Path : %s", settings.DB_PATH)
    logger.info("  Static Assets : %s (exists=%s)", settings.STATIC_DIR, settings.STATIC_DIR.exists())
    logger.info("  Host:Port     : %s:%d", settings.HOST, settings.PORT)
    logger.info("  CORS Origins  : %s", settings.CORS_ORIGINS)

    # 2. Pre-flight validation
    try:
        settings.validate_production_config()
    except RuntimeError as exc:
        logger.critical("Pre-flight configuration validation failed: %s", exc)
        sys.exit(1)

    # 3. Launch Uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        log_level=settings.LOG_LEVEL.lower(),
        access_log=True,
        workers=1
    )

if __name__ == "__main__":
    main()
