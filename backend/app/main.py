import time
from pathlib import Path
from contextlib import asynccontextmanager
from fastapi import FastAPI, APIRouter, Request
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.core.config import settings
from app.core.database import init_db
from app.core.logging_config import setup_logging, get_logger, CorrelationIdMiddleware
from app.data.seed_data import seed_all_data, DEMO_NOTICE
from app.api.health import router as health_router
from app.api.beneficiaries import router as beneficiaries_router
from app.api.fps import router as fps_router
from app.api.intent import router as intent_router
from app.api.demand_inventory import router as demand_inventory_router
from app.api.dashboard import router as dashboard_router
from app.api.admin import router as admin_router
from app.api.scarcity import router as scarcity_router
from app.api.auth import router as auth_router

# Initialize structured logging on application module load
setup_logging(log_level=settings.LOG_LEVEL)
logger = get_logger("main")

WEB_BUILD_DIR = settings.STATIC_DIR

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    app.state.start_time = time.time()
    logger.info("Initializing PDS DemandSync backend service (version=%s, env=%s)...", settings.VERSION, settings.ENVIRONMENT)

    # 1. Enforce strict configuration validation if in production mode
    settings.validate_production_config()

    # 2. Initialize SQLite Database and seed baseline synthetic dataset on startup if empty
    init_db()
    seed_all_data(recreate=False)
    logger.info("PDS DemandSync startup initialization complete. Ready to receive requests.")
    yield
    logger.info("PDS DemandSync service shutting down.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=f"{settings.PROJECT_SUBTITLE}\n\n*Smart India Hackathon (SIH) 2026 Prototype — Demo V1*\n\n**Notice**: {DEMO_NOTICE}",
    version=settings.VERSION,
    lifespan=lifespan
)

# Correlation and Request ID Middleware (placed first to trace all downstream middlewares)
app.add_middleware(CorrelationIdMiddleware)

# Standard Security Headers Middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response

# Configure CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Canonical API Routers under /api (documented in OpenAPI /docs)
api_router = APIRouter(prefix=settings.API_V1_PREFIX)
api_router.include_router(auth_router)
api_router.include_router(health_router)
api_router.include_router(beneficiaries_router)
api_router.include_router(fps_router)
api_router.include_router(intent_router)
api_router.include_router(demand_inventory_router)
api_router.include_router(dashboard_router)
api_router.include_router(admin_router)
api_router.include_router(scarcity_router)
app.include_router(api_router)

# Register Root-level compatibility aliases (hidden from OpenAPI schema to prevent duplication)
app.include_router(health_router, include_in_schema=False)
app.include_router(beneficiaries_router, include_in_schema=False)
app.include_router(fps_router, include_in_schema=False)
app.include_router(intent_router, include_in_schema=False)
app.include_router(demand_inventory_router, include_in_schema=False)
app.include_router(dashboard_router, include_in_schema=False)
app.include_router(admin_router, include_in_schema=False)
app.include_router(scarcity_router, include_in_schema=False)

# Mount Flutter Web app static assets if built
if WEB_BUILD_DIR.exists():
    app.mount("/app", StaticFiles(directory=str(WEB_BUILD_DIR), html=True), name="flutter_web")

@app.get("/", tags=["Root"])
def root():
    """Root endpoint providing service metadata, API directory, and UI links."""
    return {
        "service": settings.PROJECT_NAME,
        "subtitle": settings.PROJECT_SUBTITLE,
        "version": settings.VERSION,
        "status": "operational",
        "district": "Bengaluru Urban PDS Pilot",
        "active_cycle": "2026-09",
        "web_app_url": "/app",
        "docs_url": "/docs",
        "endpoints": {
            "health": "/health",
            "beneficiaries": "/beneficiaries",
            "fps": "/fps",
            "intent_submit": "POST /intent",
            "intents": "/intents",
            "historical_demand": "/historical-demand/{fps_id}",
            "inventory": "/inventory/{fps_id}",
            "dashboard_summary": "/dashboard/summary",
            "admin_dashboard": "/admin/dashboard",
            "admin_fps_detail": "/admin/fps/{id}",
            "forecast_generate": "POST /admin/forecast/generate",
            "forecast_lock": "POST /admin/forecast/lock",
            "dispatch_generate": "POST /admin/dispatch/generate",
            "dispatch_manifest": "GET /admin/dispatch/manifest",
            "distribution_simulate": "POST /admin/distribution/simulate",
            "distribution_records": "GET /admin/distribution/records",
            "forecast_evaluate": "GET /admin/evaluation",
            "model_calibrate": "POST /admin/calibrate",
            "command_center": "GET /admin/command-center",
            "fps_analytics": "GET /admin/fps/{id}/analytics",
            "supply_routes": "GET /admin/routes",
            "analysis_run": "POST /admin/analysis/run",
            "constraints_validate": "GET /admin/constraints/validate",
            "constraints_fps": "GET /admin/constraints/fps/{id}",
            "optimization_run": "GET /admin/optimization/run",
            "gatepasses_all": "GET /admin/gatepasses",
            "gatepass_truck": "GET /admin/gatepass/{truck_id}",
            "gatepass_advance": "POST /admin/gatepass/{id}/advance",
            "notifications_dispatch": "POST /admin/notifications/dispatch",
            "notifications_logs": "GET /admin/notifications/logs",
            "demo_reset": "POST /admin/demo/reset"
        },
        "demo_notice": DEMO_NOTICE
    }
