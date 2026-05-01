from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.v1.admin import router as admin_router
from app.api.v1.billing import router as billing_router
from app.api.v1.health import router as health_router
from app.api.v1.tester import router as tester_router
from app.core.database import engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title="AppMédecine API",
    version="0.3.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.include_router(health_router)
app.include_router(admin_router, prefix="/v1/admin")
app.include_router(billing_router, prefix="/v1/webhooks")
app.include_router(tester_router, prefix="/v1/tester")
# StaticFiles doit être monté EN DERNIER pour ne pas masquer les routes API
app.mount("/tester", StaticFiles(directory=str(Path(__file__).parent / "static"), html=True), name="tester-static")
