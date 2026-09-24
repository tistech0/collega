"""Routes collèges utilisateur — FR7 (liste), FR8-FR9 (import PDF + SSE).

Paquet découpé par domaine (chantier 5) ; `router` regroupe les sous-routeurs
dans l'ordre d'origine des routes."""

from fastapi import APIRouter

from app.api.v1.colleges import cards, catalog, imports, status

router = APIRouter(tags=["colleges"])
router.include_router(catalog.router)
router.include_router(imports.router)
router.include_router(status.router)
router.include_router(cards.router)
