"""Routes admin — pipeline OCR, monitoring, gestion utilisateurs (Story 1.4, 7.6-7.8).

Paquet découpé par domaine (chantier 5). Toutes les routes sont protégées par
HTTP Basic Auth. Aucun chemin ne se recoupe entre sous-routeurs : l'ordre
d'inclusion n'influe pas sur le routage."""

from fastapi import APIRouter

from app.api.v1.admin import colleges, config, jobs, usage, users

router = APIRouter(tags=["admin"])
router.include_router(colleges.router)
router.include_router(jobs.router)
router.include_router(users.router)
router.include_router(usage.router)
router.include_router(config.router)
