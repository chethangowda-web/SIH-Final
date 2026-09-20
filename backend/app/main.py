import time
from pathlib import Path
from contextlib import asynccontextmanager
from fastapi import FastAPI, APIRouter, Request, Depends, Query
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import sqlite3
from app.core.config import settings
from app.core.database import init_db, get_db
from app.core.logging_config import setup_logging, get_logger, CorrelationIdMiddleware
from app.data.seed_data import seed_all_data, DEMO_NOTICE
from app.models.schemas import ChoiceWindowStatusOut
from app.api.health import router as health_router
from app.api.beneficiaries import router as beneficiaries_router
from app.api.fps import router as fps_router
from app.api.intent import router as intent_router
from app.api.demand_inventory import router as demand_inventory_router
from app.api.dashboard import router as dashboard_router
from app.api.admin import router as admin_router
from app.api.scarcity import router as scarcity_router
from app.api.auth import router as auth_router
from app.api.anomaly import router as anomaly_router
from app.api.routing import router as routing_router
from app.api.csv_import import router as csv_import_router
from app.api.reports import router as reports_router
from app.api.feedback import router as feedback_router
from app.api.webhook import router as webhook_router
from app.api.officer import router as officer_router
from app.api.grain_atm import router as grain_atm_router
from app.api.tts import router as tts_router

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

    # 2. Ensure database schema & seed baseline datasets are initialized
    try:
        init_db()
    except Exception as e:
        logger.warning(f"Database startup check warning: {e}")

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
    allow_origin_regex=r"^https?://.*$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Canonical API Routers under /api (documented in OpenAPI /docs)
api_router = APIRouter(prefix=settings.API_V1_PREFIX)

@api_router.get("/choice-window/status", tags=["Choice Window"], response_model=ChoiceWindowStatusOut)
def public_choice_window_status_api(
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Public real-time query for choice window status and planning-cycle day without requiring session auth."""
    from app.services.planning_cycle_engine import planning_cycle_engine
    return planning_cycle_engine.get_cycle_state(db, cycle_id.strip())

@app.get("/choice-window/status", tags=["Choice Window"], response_model=ChoiceWindowStatusOut, include_in_schema=False)
def public_choice_window_status_root(
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Public real-time query alias at root level."""
    from app.services.planning_cycle_engine import planning_cycle_engine
    return planning_cycle_engine.get_cycle_state(db, cycle_id.strip())

api_router.include_router(auth_router)
api_router.include_router(health_router)
api_router.include_router(beneficiaries_router)
api_router.include_router(fps_router)
api_router.include_router(intent_router)
api_router.include_router(demand_inventory_router)
api_router.include_router(dashboard_router)
api_router.include_router(admin_router)
api_router.include_router(scarcity_router)
api_router.include_router(anomaly_router)
api_router.include_router(routing_router)
api_router.include_router(csv_import_router)
api_router.include_router(reports_router)
api_router.include_router(feedback_router)
api_router.include_router(webhook_router)
api_router.include_router(officer_router)
api_router.include_router(grain_atm_router)
api_router.include_router(tts_router)
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
app.include_router(anomaly_router, include_in_schema=False)
app.include_router(routing_router, include_in_schema=False)
app.include_router(csv_import_router, include_in_schema=False)
app.include_router(reports_router, include_in_schema=False)
app.include_router(feedback_router, include_in_schema=False)
app.include_router(webhook_router, include_in_schema=False)
app.include_router(officer_router, include_in_schema=False)
app.include_router(grain_atm_router, include_in_schema=False)
app.include_router(tts_router, include_in_schema=False)

# Mount Flutter Web app static assets if built
if WEB_BUILD_DIR.exists():
    app.mount("/app", StaticFiles(directory=str(WEB_BUILD_DIR), html=True), name="flutter_web")

    if (WEB_BUILD_DIR / "assets").exists():
        app.mount("/assets", StaticFiles(directory=str(WEB_BUILD_DIR / "assets")), name="flutter_assets")
    if (WEB_BUILD_DIR / "canvaskit").exists():
        app.mount("/canvaskit", StaticFiles(directory=str(WEB_BUILD_DIR / "canvaskit")), name="flutter_canvaskit")

    @app.get("/flutter_bootstrap.js", include_in_schema=False)
    async def serve_bootstrap_root():
        f = WEB_BUILD_DIR / "flutter_bootstrap.js"
        if f.exists():
            from fastapi.responses import FileResponse
            resp = FileResponse(f, media_type="application/javascript")
            resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
            return resp
        from fastapi import Response
        return Response(status_code=404)

    @app.get("/main.dart.js", include_in_schema=False)
    async def serve_main_dart_root():
        f = WEB_BUILD_DIR / "main.dart.js"
        if f.exists():
            from fastapi.responses import FileResponse
            resp = FileResponse(f, media_type="application/javascript")
            resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
            return resp
        from fastapi import Response
        return Response(status_code=404)

    @app.get("/manifest.json", include_in_schema=False)
    async def serve_manifest_root():
        f = WEB_BUILD_DIR / "manifest.json"
        if f.exists():
            from fastapi.responses import FileResponse
            return FileResponse(f, media_type="application/json")
        from fastapi import Response
        return Response(status_code=404)

    @app.get("/favicon.png", include_in_schema=False)
    async def serve_favicon_root():
        f = WEB_BUILD_DIR / "favicon.png"
        if f.exists():
            from fastapi.responses import FileResponse
            return FileResponse(f, media_type="image/png")
        from fastapi import Response
        return Response(status_code=404)

    @app.get("/app/{full_path:path}", include_in_schema=False)
    async def serve_flutter_spa(full_path: str):
        """Fallback handler for Flutter Web SPA client-side routing."""
        target_file = WEB_BUILD_DIR / full_path
        if target_file.exists() and target_file.is_file():
            from fastapi.responses import FileResponse
            resp = FileResponse(target_file)
            if target_file.name in ("index.html", "flutter_bootstrap.js", "flutter_service_worker.js", "version.json", "main.dart.js"):
                resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
                resp.headers["Pragma"] = "no-cache"
            return resp
        index_file = WEB_BUILD_DIR / "index.html"
        if index_file.exists():
            from fastapi.responses import FileResponse
            resp = FileResponse(index_file)
            resp.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
            resp.headers["Pragma"] = "no-cache"
            return resp
        return RedirectResponse(url="/")

@app.get("/", tags=["Root"])
def root(request: Request):
    """Root endpoint providing service metadata, API directory, and UI links."""
    accept_header = request.headers.get("accept", "")
    if "text/html" in accept_header and WEB_BUILD_DIR.exists():
        return RedirectResponse(url="/app/")
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
