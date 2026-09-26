"""Pages publiques pour App Store Connect : sans authentification, et hors
Cloudflare Access (application « bypass » sur le chemin /legal)."""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.services import legal_pages

router = APIRouter(prefix="/legal", default_response_class=HTMLResponse)


@router.get("/privacy")
async def privacy() -> HTMLResponse:
    return HTMLResponse(legal_pages.privacy_page())


@router.get("/terms")
async def terms() -> HTMLResponse:
    return HTMLResponse(legal_pages.terms_page())


@router.get("/support")
async def support() -> HTMLResponse:
    return HTMLResponse(legal_pages.support_page())
