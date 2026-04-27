# Stub pour Story 1.3 — génération de fiches via Claude + retry backoff (NFR10)
from arq import ArqRedis


async def generate_college_cards(ctx: dict, college_id: str, user_id: str) -> dict:
    """Génère les fiches d'un collège via Claude API — implémenté en Story 1.3."""
    raise NotImplementedError("generation_worker implémenté en Story 1.3")


class WorkerSettings:
    functions = [generate_college_cards]
    on_startup = None
    on_shutdown = None
