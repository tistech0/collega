"""
Tests de validation de la migration initiale.
Ces tests nécessitent une connexion PostgreSQL — à exécuter avec docker-compose up.

Pour lancer : pytest tests/test_migrations.py --require-db
"""
import pytest


EXPECTED_TABLES_AFTER_MIGRATION = {"users", "colleges", "alembic_version"}
FORBIDDEN_TABLES = {"items", "flash_cards", "generation_jobs"}


@pytest.mark.skip(reason="Nécessite une base PostgreSQL réelle (docker-compose up db)")
@pytest.mark.asyncio
async def test_migration_creates_only_story_1_1_tables() -> None:
    """Vérifie que la migration 001 crée uniquement users et colleges."""
    from sqlalchemy import text
    from sqlalchemy.ext.asyncio import create_async_engine

    from app.core.config import settings

    engine = create_async_engine(settings.database_url)
    try:
        async with engine.connect() as conn:
            result = await conn.execute(
                text("SELECT tablename FROM pg_tables WHERE schemaname = 'public'")
            )
            tables = {row[0] for row in result}
    finally:
        await engine.dispose()

    for forbidden in FORBIDDEN_TABLES:
        assert forbidden not in tables, (
            f"Table '{forbidden}' ne doit pas exister en Story 1.1 — créée en Story 1.2/1.3"
        )

    assert "users" in tables, "Table 'users' manquante après migration 001"
    assert "colleges" in tables, "Table 'colleges' manquante après migration 001"
