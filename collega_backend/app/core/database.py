from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


# Index sur expression qu'Alembic ne sait pas comparer (il les voit toujours
# « différents ») : créés par migration SQL, jamais par les modèles, et exclus de
# l'autogénération pour qu'aucune migration générée ne les supprime.
ALEMBIC_UNMANAGED_INDEXES = frozenset({"idx_flash_cards_fts"})


def alembic_include_object(obj, name, type_, reflected, compare_to) -> bool:
    return not (type_ == "index" and name in ALEMBIC_UNMANAGED_INDEXES)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session
