from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api.v1.admin import router as admin_router
from app.api.v1.auth import router as auth_router
from app.api.v1.billing import router as billing_router
from app.api.v1.colleges import router as colleges_router
from app.api.v1.drill import router as drill_router
from app.api.v1.flash_cards import router as flash_cards_router
from app.api.v1.health import router as health_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.tester import router as tester_router
from app.core.database import engine
from app.core.limiter import limiter


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title="AppMédecine API",
    version="0.3.0",
    docs_url=None,
    redoc_url=None,
    lifespan=lifespan,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(health_router)
app.include_router(auth_router, prefix="/v1/auth")
app.include_router(colleges_router, prefix="/v1")
app.include_router(flash_cards_router, prefix="/v1")
app.include_router(drill_router, prefix="/v1")
app.include_router(notifications_router, prefix="/v1")
app.include_router(admin_router, prefix="/v1/admin")
app.include_router(billing_router, prefix="/v1/webhooks")
app.include_router(tester_router, prefix="/v1/tester")
# StaticFiles doit être monté EN DERNIER pour ne pas masquer les routes API
app.mount("/tester", StaticFiles(directory=str(Path(__file__).parent / "static"), html=True), name="tester-static")
